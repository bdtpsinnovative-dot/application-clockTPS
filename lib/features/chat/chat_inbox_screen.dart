import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../widgets/work_ui.dart';
import 'chat_models.dart';
import 'chat_room_screen.dart';
import 'chat_service.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({
    super.key,
    required this.currentUser,
    this.onOpenNotifications,
    this.notificationCount = 0,
  });

  final AppUser currentUser;
  final VoidCallback? onOpenNotifications;
  final int notificationCount;

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  String _assignFilter = 'all'; // all, mine, unassigned
  String _brandFilter = 'all'; // all, terrahome, zenslab, wallcraft, emberandash
  String _searchQuery = '';
  Timer? _pollingTimer;

  final List<Map<String, String>> _brands = [
    {'slug': 'all', 'label': 'ทุกแบรนด์'},
    {'slug': 'terrahome', 'label': 'Terra Home'},
    {'slug': 'zenslab', 'label': 'Zenslab'},
    {'slug': 'wallcraft', 'label': 'Wallcraft'},
    {'slug': 'emberandash', 'label': 'Ember & Ash'},
  ];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _pollingTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final list = await ChatService.instance.fetchConversations(
      filter: _assignFilter,
      brand: _brandFilter,
      currentUserId: widget.currentUser.id.toString(),
      searchQuery: _searchQuery,
    );

    if (!mounted) return;
    setState(() {
      _conversations = list;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _loadConversations(silent: true);
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} น.';
    if (diff.inHours < 24) return '${diff.inHours} ชม.';
    if (diff.inDays < 7) return '${diff.inDays} วัน';
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.currentUser.id.toString();
    final unassignedCount =
        _conversations.where((c) => !c.isAssigned).length;
    final myCount = _conversations.where((c) {
      return c.assignedTo == myUid || c.assignedAgentIds.contains(myUid);
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(unassignedCount, myCount),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadConversations(),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _conversations.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 56,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'ไม่มีรายการแชทในหมวดนี้',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          itemCount: _conversations.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conv = _conversations[index];
                            return _buildConversationCard(conv);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 12,
        20,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [workBlue, workSky],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กล่องข้อความลูกค้า',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Omnichannel Chat (LINE & Facebook)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () => _loadConversations(),
                tooltip: 'รีเฟรช',
              ),
              if (widget.onOpenNotifications != null)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                      onPressed: widget.onOpenNotifications,
                      tooltip: 'การแจ้งเตือน',
                    ),
                    if (widget.notificationCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            widget.notificationCount > 99 ? '99+' : '${widget.notificationCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อลูกค้า, ข้อความ, แบรนด์...',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(int unassignedCount, int myCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          // Assign Filter Chips
          Row(
            children: [
              _buildFilterChip('all', 'ทั้งหมด (${_conversations.length})'),
              const SizedBox(width: 8),
              _buildFilterChip('mine', 'ของฉัน ($myCount)'),
              const SizedBox(width: 8),
              _buildFilterChip(
                'unassigned',
                'รอรับงาน ($unassignedCount)',
                isWarning: unassignedCount > 0,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Brand Filter Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _brands.map((b) {
                final isSelected = _brandFilter == b['slug'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      b['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? workBlue : const Color(0xFF64748B),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _brandFilter = b['slug']!);
                      _loadConversations();
                    },
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFFEFF6FF),
                    side: BorderSide(
                      color: isSelected ? workBlue : Colors.transparent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isWarning = false}) {
    final isSelected = _assignFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _assignFilter = key);
          _loadConversations();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isWarning
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFEFF6FF))
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? (isWarning ? const Color(0xFFF97316) : workBlue)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isWarning ? const Color(0xFFC2410C) : workBlue)
                    : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation conv) {
    final hasUnread = conv.unreadCount > 0;
    final isUnassigned = !conv.isAssigned;

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversation: conv,
              currentUser: widget.currentUser,
            ),
          ),
        );
        _loadConversations(silent: true);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? workBlue.withValues(alpha: 0.35)
                : const Color(0xFFF1F5F9),
            width: hasUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: conv.customerAvatar != null &&
                          conv.customerAvatar!.isNotEmpty
                      ? NetworkImage(conv.customerAvatar!)
                      : null,
                  child: conv.customerAvatar == null ||
                          conv.customerAvatar!.isEmpty
                      ? Text(
                          conv.customerName.characters.firstOrNull ?? '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: _getPlatformColor(conv.platform),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      conv.platform == 'line' ? 'L' : 'F',
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conv.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(conv.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread ? workBlue : const Color(0xFF94A3B8),
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          conv.brand.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: workBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isUnassigned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'รอรับงาน',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        )
                      else
                        Text(
                          conv.assignedToName ?? 'มีผู้รับแล้ว',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessageText ?? 'ไม่มีข้อความ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF64748B),
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conv.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
