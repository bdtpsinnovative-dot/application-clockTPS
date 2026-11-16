import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../widgets/work_ui.dart';
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
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadMessages();
    ChatService.instance.markAsRead(_conversation.id);
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadMessages(silent: true);
      }
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
      });
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ กรุณาลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _handleClaimChat() async {
    final senderName = widget.currentUser.nickname.isNotEmpty
        ? widget.currentUser.nickname
        : widget.currentUser.firstName.isNotEmpty
            ? widget.currentUser.firstName
            : widget.currentUser.email;

    final success = await ChatService.instance.assignConversation(
      convId: _conversation.id,
      agentId: widget.currentUser.id.toString(),
      agentName: senderName,
    );

    if (!mounted) return;
    if (success) {
      setState(() {
        _conversation = ChatConversation(
          id: _conversation.id,
          platform: _conversation.platform,
          brand: _conversation.brand,
          customerName: _conversation.customerName,
          customerAvatar: _conversation.customerAvatar,
          externalUserId: _conversation.externalUserId,
          assignedTo: widget.currentUser.id.toString(),
          assignedToName: senderName,
          unreadCount: 0,
          lastMessageText: _conversation.lastMessageText,
          lastMessageAt: _conversation.lastMessageAt,
          metadata: {
            ..._conversation.metadata,
            'assigned_agent_ids': [widget.currentUser.id.toString()],
          },
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณได้รับงานแชทนี้แล้ว')),
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
    final isMyChat = _conversation.assignedTo == widget.currentUser.id.toString() ||
        _conversation.assignedAgentIds.contains(widget.currentUser.id.toString());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
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
                            fontSize: 16,
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _conversation.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _conversation.brand.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: workBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _conversation.isAssigned
                            ? (_conversation.assignedToName ?? 'มีผู้รับแล้ว')
                            : 'รอรับงาน',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _conversation.isAssigned
                              ? const Color(0xFF64748B)
                              : const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_conversation.isAssigned || !isMyChat)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _handleClaimChat,
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('รับงาน', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isAgent = msg.isAgent;
                            return _buildMessageBubble(msg, isAgent);
                          },
                        ),
            ),
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

  Widget _buildMessageBubble(ChatMessage msg, bool isAgent) {
    final timeStr = DateFormat('HH:mm').format(msg.createdAt);
    final hasMedia = (msg.mediaUrl ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isAgent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
          if (isAgent) const SizedBox(width: 4),
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
