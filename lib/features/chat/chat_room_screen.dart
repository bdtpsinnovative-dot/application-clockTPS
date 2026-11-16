import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../widgets/user_avatar.dart';
import 'assign_agent_bottom_sheet.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.conversation,
    required this.currentUser,
  });

  final ChatConversation conversation;
  final AppUser currentUser;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late ChatConversation _conversation;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  Map<String, ChatAgentUser> _usersMap = {};
  bool _isLoading = true;
  bool _isSending = false;
  bool _isAssigning = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadUsers();
    _loadMessages();
    ChatService.instance.markAsRead(_conversation.id);
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadMessages(silent: true);
      }
    });
  }

  Future<void> _loadUsers() async {
    final users = await ChatService.instance.fetchActiveUsers();
    if (!mounted) return;
    setState(() {
      _usersMap = {for (final u in users) u.id: u};
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final msgs = await ChatService.instance.fetchMessages(_conversation.id);
    if (!mounted) return;

    final hasNew = msgs.length != _messages.length;
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });

    if (hasNew) {
      _scrollToBottom();
      ChatService.instance.markAsRead(_conversation.id);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() => _isSending = true);

    final senderName = widget.currentUser.nickname.isNotEmpty
        ? widget.currentUser.nickname
        : widget.currentUser.firstName.isNotEmpty
            ? widget.currentUser.firstName
            : widget.currentUser.email;

    final newMsg = await ChatService.instance.sendMessage(
      conversation: _conversation,
      content: text,
      senderId: widget.currentUser.id.toString(),
      senderName: senderName,
      senderAvatar: widget.currentUser.avatarUrl,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (newMsg != null) {
      setState(() {
        _messages.add(newMsg);
        // If chat was unassigned, sending a message automatically assigns it to current user
        if (!_conversation.isAssigned) {
          _conversation = _conversation.copyWith(
            assignedTo: widget.currentUser.id.toString(),
            assignedToName: senderName,
          );
        }
      });
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ กรุณาลองใหม่อีกครั้ง')),
      );
    }
  }

  /// Open Assign Agent Bottom Sheet (Matches Image 2)
  void _handleOpenAssignSheet() {
    AssignAgentBottomSheet.show(
      context,
      conversation: _conversation,
      onAssigned: (updated) {
        setState(() {
          _conversation = updated;
        });
      },
    );
  }

  /// Random Assign / 🎲 สุ่มคนดูแล
  Future<void> _handleRandomAssign() async {
    if (_isAssigning) return;
    setState(() => _isAssigning = true);

    final picked = await ChatService.instance.randomAssign(_conversation);
    if (!mounted) return;
    setState(() => _isAssigning = false);

    if (picked != null) {
      setState(() {
        _conversation = _conversation.copyWith(
          assignedTo: picked.id,
          assignedToName: picked.displayName,
          metadata: {
            ..._conversation.metadata,
            'assigned_agent_ids': [picked.id],
          }..remove('assigned_group_id')..remove('assigned_group_name'),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('สุ่มผู้ดูแลสำเร็จ: ${picked.displayName}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถสุ่มผู้ดูแลได้ในขณะนี้')),
      );
    }
  }

  /// Edit customer name dialog
  Future<void> _handleEditCustomerName() async {
    final nameCtrl = TextEditingController(text: _conversation.customerName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'แก้ไขชื่อลูกค้า',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ระบุชื่อลูกค้า...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final newName = nameCtrl.text.trim();
      final ok = await ChatService.instance.updateCustomerName(_conversation.id, newName);
      if (ok && mounted) {
        setState(() {
          _conversation = _conversation.copyWith(customerName: newName);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตชื่อลูกค้าเรียบร้อยแล้ว')),
        );
      }
    }
  }

  /// Toggle resolved / active status
  Future<void> _handleToggleStatus() async {
    final isResolved = _conversation.status == 'resolved';
    final nextStatus = isResolved ? 'active' : 'resolved';
    final ok = await ChatService.instance.updateStatus(_conversation.id, nextStatus);
    if (ok && mounted) {
      setState(() {
        _conversation = _conversation.copyWith(status: nextStatus);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'resolved' ? 'ปิดเคสการสนทนานี้แล้ว' : 'เปิดเคสการสนทนาอีกครั้ง',
          ),
          backgroundColor:
              nextStatus == 'resolved' ? const Color(0xFF64748B) : const Color(0xFF10B981),
        ),
      );
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'line':
        return const Color(0xFF06C755);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE1306C);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bInfo = getBrandInfo(_conversation.brand);
    final assignedUser =
        _conversation.assignedTo != null ? _usersMap[_conversation.assignedTo] : null;
    final assignedAvatar = assignedUser != null
        ? UserAvatar.resolveAvatarUrl(assignedUser.avatarUrl)
        : '';
    final assignedDisplayName =
        assignedUser?.displayName ?? _conversation.assignedToName ?? '';
    final isGroup = _conversation.assignedGroupId != null &&
        _conversation.assignedGroupId!.isNotEmpty;
    final groupName = _conversation.assignedGroupName ?? 'กลุ่มแชท';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        titleSpacing: 0,
        title: InkWell(
          onTap: _handleEditCustomerName,
          child: Row(
            children: [
              // Customer Avatar with platform badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: _conversation.customerAvatar != null &&
                            _conversation.customerAvatar!.isNotEmpty
                        ? NetworkImage(_conversation.customerAvatar!)
                        : null,
                    child: _conversation.customerAvatar == null ||
                            _conversation.customerAvatar!.isEmpty
                        ? Text(
                            _conversation.customerName.isNotEmpty
                                ? _conversation.customerName.characters.first
                                : '?',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _getPlatformColor(_conversation.platform),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        _conversation.platform == 'line' ? 'L' : 'F',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Customer Name + Brand & Status Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _conversation.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        // Brand Badge (Logo + Name)
                        if (bInfo.logoUrl.isNotEmpty) ...[
                          CircleAvatar(
                            radius: 5,
                            backgroundColor: Colors.transparent,
                            backgroundImage: NetworkImage(bInfo.logoUrl),
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          bInfo.shortLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: bInfo.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: _conversation.status == 'resolved'
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _conversation.status == 'resolved' ? 'ปิดเคส' : 'เปิดอยู่',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _conversation.status == 'resolved'
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // 1. Assigned Agent Dropdown Button (Matches Image 2)
          Center(
            child: InkWell(
              onTap: _handleOpenAssignSheet,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: _conversation.isAssigned
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _conversation.isAssigned
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFFDBA74),
                  ),
                ),
                child: isGroup
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.group_rounded,
                                size: 12, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 65),
                            child: Text(
                              groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 14, color: Color(0xFF2563EB)),
                        ],
                      )
                    : _conversation.isAssigned
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: const Color(0xFFDBEAFE),
                                backgroundImage: assignedAvatar.isNotEmpty
                                    ? NetworkImage(assignedAvatar)
                                    : null,
                                child: assignedAvatar.isEmpty
                                    ? Text(
                                        assignedDisplayName.isNotEmpty
                                            ? assignedDisplayName.characters.first
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E40AF),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 65),
                                child: Text(
                                  assignedDisplayName.isNotEmpty
                                      ? assignedDisplayName
                                      : 'ผู้ดูแล',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 14, color: Color(0xFF64748B)),
                            ],
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '⚠️ รอผู้ดูแล',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 14, color: Color(0xFFEA580C)),
                            ],
                          ),
              ),
            ),
          ),

          // 2. Random Assign / 🔀 สุ่มคนดูแล
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: _isAssigning ? null : _handleRandomAssign,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _isAssigning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shuffle_rounded,
                          color: Colors.white, size: 16),
                ),
              ),
            ),
          ),

          // 3. More Menu (Popup)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
            padding: EdgeInsets.zero,
            onSelected: (val) {
              if (val == 'edit_name') {
                _handleEditCustomerName();
              } else if (val == 'toggle_status') {
                _handleToggleStatus();
              } else if (val == 'copy_id') {
                if (_conversation.externalUserId != null) {
                  Clipboard.setData(ClipboardData(text: _conversation.externalUserId!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('คัดลอก ID ลูกค้าแล้ว')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit_name',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('แก้ไขชื่อลูกค้า', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_status',
                child: Row(
                  children: [
                    Icon(
                      _conversation.status == 'resolved'
                          ? Icons.check_circle_outline_rounded
                          : Icons.archive_outlined,
                      size: 18,
                      color: _conversation.status == 'resolved'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _conversation.status == 'resolved'
                          ? 'เปิดเคสการสนทนาอีกครั้ง'
                          : 'ปิดเคสการสนทนา',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if ((_conversation.externalUserId ?? '').isNotEmpty)
                const PopupMenuItem(
                  value: 'copy_id',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text('คัดลอก ID ลูกค้า', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'ยังไม่มีข้อความในการสนทนานี้',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isAgent = msg.isAgent;
                            return _buildMessageBubble(msg, isAgent);
                          },
                        ),
            ),

            // Quick Replies Tray (คำตอบด่วน)
            _buildQuickRepliesTray(),

            // Bottom Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl, {String? caption}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrl: imageUrl,
          caption: caption,
          customerName: _conversation.customerName,
        ),
      ),
    );
  }

  Widget _buildQuickRepliesTray() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(left: 4, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFF59E0B)),
                  SizedBox(width: 2),
                  Text(
                    'ด่วน:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...kQuickReplies.map((reply) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _textController.text = reply;
                    _textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: reply.length),
                    );
                  });
                  _focusNode.requestFocus();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text(
                      reply,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isAgent) {
    final timeStr = DateFormat('HH:mm').format(msg.createdAt);
    final hasMedia = (msg.mediaUrl ?? '').isNotEmpty;

    // Agent Avatar resolution
    String? agentAvatar;
    if (isAgent) {
      if ((msg.senderAvatar ?? '').isNotEmpty) {
        agentAvatar = UserAvatar.resolveAvatarUrl(msg.senderAvatar);
      } else if (msg.senderId != null && _usersMap.containsKey(msg.senderId)) {
        agentAvatar = UserAvatar.resolveAvatarUrl(_usersMap[msg.senderId]!.avatarUrl);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isAgent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left: Customer Avatar (for customer messages)
          if (!isAgent) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: _conversation.customerAvatar != null &&
                      _conversation.customerAvatar!.isNotEmpty
                  ? NetworkImage(_conversation.customerAvatar!)
                  : null,
              child: _conversation.customerAvatar == null ||
                      _conversation.customerAvatar!.isEmpty
                  ? Text(
                      _conversation.customerName.characters.firstOrNull ?? 'C',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // Middle: Message Bubble + Timestamp
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAgent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isAgent && (msg.senderName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4),
                    child: Text(
                      msg.senderName!,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ),
                if (msg.isImage && hasMedia)
                  _buildImageBubble(msg, isAgent)
                else if (msg.isFile && hasMedia)
                  _buildFileBubble(msg, isAgent)
                else
                  _buildTextBubble(msg, isAgent),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),

          // Right: Agent Avatar (for staff/agent messages)
          if (isAgent) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFDBEAFE),
              backgroundImage: (agentAvatar != null && agentAvatar.isNotEmpty)
                  ? NetworkImage(agentAvatar)
                  : null,
              child: (agentAvatar == null || agentAvatar.isEmpty)
                  ? Text(
                      (msg.senderName ?? 'A').isNotEmpty
                          ? (msg.senderName ?? 'A').characters.first
                          : 'A',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageBubble(ChatMessage msg, bool isAgent) {
    final hasCaption = msg.content.isNotEmpty &&
        msg.content != '📷 [รูปภาพ]' &&
        !msg.content.startsWith('📷');

    return Container(
      decoration: BoxDecoration(
        color: isAgent ? const Color(0xFF2563EB) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isAgent ? const Radius.circular(16) : Radius.zero,
          bottomRight: isAgent ? Radius.zero : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isAgent ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isAgent ? const Radius.circular(16) : Radius.zero,
          bottomRight: isAgent ? Radius.zero : const Radius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _openImageViewer(
                context,
                msg.mediaUrl!,
                caption: hasCaption ? msg.content : null,
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 160,
                      maxWidth: 260,
                      maxHeight: 340,
                    ),
                    child: Image.network(
                      msg.mediaUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 200,
                          height: 180,
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stackTrace) {
                        return Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          color: const Color(0xFFF8FAFC),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.image_search_rounded,
                                color: Color(0xFF2563EB),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'รูปภาพจากแชท',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'แตะเพื่อเปิดดูภาพเต็มจอ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 3),
                        Text(
                          'ดูรูป',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasCaption)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isAgent ? Colors.white : const Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileBubble(ChatMessage msg, bool isAgent) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAgent ? const Color(0xFF2563EB) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isAgent ? const Radius.circular(16) : Radius.zero,
          bottomRight: isAgent ? Radius.zero : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isAgent ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () {
          if ((msg.mediaUrl ?? '').isNotEmpty) {
            launchUrl(Uri.parse(msg.mediaUrl!), mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isAgent ? Colors.white : const Color(0xFF2563EB)).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.attach_file_rounded,
                color: isAgent ? Colors.white : const Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.content.isNotEmpty ? msg.content : 'ไฟล์แนบ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isAgent ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'แตะเพื่อเปิดไฟล์ ↗',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAgent ? Colors.white70 : const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(ChatMessage msg, bool isAgent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isAgent ? const Color(0xFF2563EB) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isAgent ? const Radius.circular(16) : Radius.zero,
          bottomRight: isAgent ? Radius.zero : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isAgent ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        msg.content,
        style: TextStyle(
          fontSize: 14,
          color: isAgent ? Colors.white : const Color(0xFF0F172A),
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'พิมพ์ข้อความตอบกลับลูกค้า...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF2563EB),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSending ? null : _handleSendMessage,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.caption,
    this.customerName,
  });

  final String imageUrl;
  final String? caption;
  final String? customerName;

  Future<void> _launchExternal(BuildContext context) async {
    try {
      final uri = Uri.parse(imageUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดลิงก์รูปภาพได้')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          customerName ?? 'รูปภาพ',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            tooltip: 'เปิดในเบราว์เซอร์',
            onPressed: () => _launchExternal(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      final total = progress.expectedTotalBytes;
                      final loaded = progress.cumulativeBytesLoaded;
                      final val = (total != null && total > 0) ? (loaded / total) : null;
                      return Center(
                        child: CircularProgressIndicator(
                          value: val,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (ctx, error, stackTrace) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white60,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ไม่สามารถแสดงผลผ่านหน้าจอได้โดยตรง',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchExternal(context),
                              icon: const Icon(Icons.open_in_browser_rounded),
                              label: const Text('เปิดดูรูปภาพในแท็บใหม่ ↗'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (caption != null && caption!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black.withValues(alpha: 0.7),
                child: Text(
                  caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
