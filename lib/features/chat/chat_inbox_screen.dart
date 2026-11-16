import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/work_ui.dart';
import 'assign_agent_bottom_sheet.dart';
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
  Map<String, ChatAgentUser> _usersMap = {};
  bool _isLoading = true;

  // Filters matching web (Image 1)
  String _assignFilter = 'all'; // all, mine, unassigned
  String _statusFilter = 'active'; // unread, active, resolved, all
  String _platformFilter = 'all'; // all, line, facebook, instagram
  String _brandFilter = 'all'; // all, terrahome, zenslab, wallcraft, emberandash
  String _searchQuery = '';
  Timer? _pollingTimer;

  final List<Map<String, String>> _platforms = [
    {'key': 'all', 'label': 'All'},
    {'key': 'line', 'label': 'LINE'},
    {'key': 'facebook', 'label': 'FB'},
    {'key': 'instagram', 'label': 'IG'},
  ];

  List<Map<String, String>> _brands = [
    {'slug': 'all', 'label': 'All'},
    {'slug': 'terrahome', 'label': 'TERRA'},
    {'slug': 'zenslab', 'label': 'ZENSLAB'},
    {'slug': 'emberandash', 'label': 'EMBER & ASH'},
    {'slug': 'wallcraft', 'label': 'WALLCRAFT'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadChannels();
    _loadConversations();
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    final channels = await ChatService.instance.fetchChannels();
    if (!mounted || channels.isEmpty) return;

    final seen = <String>{};
    final dynamicBrands = <Map<String, String>>[
      {'slug': 'all', 'label': 'All'},
    ];
    for (final ch in channels) {
      final slug = ch.brandSlug.toLowerCase().trim();
      if (slug.isNotEmpty && seen.add(slug)) {
        final short = slug == 'terrahome'
            ? 'TERRA'
            : slug == 'zenslab'
                ? 'ZENSLAB'
                : slug == 'emberandash'
                    ? 'EMBER & ASH'
                    : slug == 'wallcraft'
                        ? 'WALLCRAFT'
                        : ch.brandName.isNotEmpty
                            ? ch.brandName.toUpperCase()
                            : slug.toUpperCase();
        dynamicBrands.add({'slug': slug, 'label': short});
      }
    }

    if (dynamicBrands.length > 1) {
      setState(() {
        _brands = dynamicBrands;
      });
    }
  }

  Future<void> _loadUsers() async {
    final users = await ChatService.instance.fetchActiveUsers();
    if (!mounted) return;
    setState(() {
      _usersMap = {for (final u in users) u.id: u};
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final list = await ChatService.instance.fetchConversations(
      filter: _assignFilter,
      statusFilter: _statusFilter,
      platformFilter: _platformFilter,
      brandFilter: _brandFilter,
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
        return const Color(0xFF0084FF);
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
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays < 7) {
      return DateFormat('E HH:mm').format(dt);
    }
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.currentUser.id.toString();
    final unreadTotal =
        _conversations.where((c) => c.unreadCount > 0).fold<int>(0, (sum, c) => sum + c.unreadCount);
    final myCount = _conversations.where((c) {
      return c.assignedTo == myUid || c.assignedAgentIds.contains(myUid);
    }).length;
    final unassignedCount = _conversations.where((c) => !c.isAssigned).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(unreadTotal, myCount, unassignedCount),
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
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 8),
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
        18,
        MediaQuery.paddingOf(context).top + 10,
        18,
        14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [workBlue, workSky],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'กล่องข้อความลูกค้า',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Omnichannel Chat (LINE / FB / IG)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
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
                      icon: const Icon(Icons.notifications_none_rounded,
                          color: Colors.white),
                      onPressed: widget.onOpenNotifications,
                      tooltip: 'การแจ้งเตือน',
                    ),
                    if (widget.notificationCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            widget.notificationCount > 99
                                ? '99+'
                                : '${widget.notificationCount}',
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
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อลูกค้า, ข้อความ, แบรนด์...',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF64748B), size: 20),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(int unreadTotal, int myCount, int unassignedCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status Filter (🔴 ยังไม่อ่าน, เปิดอยู่, ปิดเคสแล้ว, ทั้งหมด)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(
                  key: 'unread',
                  label: 'ยังไม่อ่าน',
                  count: unreadTotal > 0 ? unreadTotal : null,
                  hasDot: true,
                  dotColor: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(key: 'active', label: 'เปิดอยู่'),
                const SizedBox(width: 6),
                _buildStatusChip(key: 'resolved', label: 'ปิดเคสแล้ว'),
                const SizedBox(width: 6),
                _buildStatusChip(key: 'all', label: 'ทั้งหมด'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Row 2: Platform Filter (All, LINE, FB, IG)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _platforms.map((p) {
                final isSelected = _platformFilter == p['key'];
                Color activeColor;
                if (p['key'] == 'line') {
                  activeColor = const Color(0xFF06C755);
                } else if (p['key'] == 'facebook') {
                  activeColor = const Color(0xFF0084FF);
                } else if (p['key'] == 'instagram') {
                  activeColor = const Color(0xFFE1306C);
                } else {
                  activeColor = const Color(0xFF2563EB);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _platformFilter = p['key']!);
                      _loadConversations();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? activeColor
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p['key'] == 'line') ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF06C755),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else if (p['key'] == 'facebook') ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0084FF),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else if (p['key'] == 'instagram') ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE1306C),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            p['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Row 3: Brand Filter with Logos (All, TERRA, ZENSLAB, EMBER & ASH, WALLCRAFT)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _brands.map((b) {
                final isSelected = _brandFilter == b['slug'];
                final bInfo = b['slug'] != 'all' ? getBrandInfo(b['slug']) : null;
                final brandColor = bInfo != null ? bInfo.color : const Color(0xFF334155);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _brandFilter = b['slug']!);
                      _loadConversations();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandColor
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? brandColor
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (bInfo != null && bInfo.logoUrl.isNotEmpty) ...[
                            CircleAvatar(
                              radius: 6,
                              backgroundColor: Colors.transparent,
                              backgroundImage: NetworkImage(bInfo.logoUrl),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            b['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : brandColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String key,
    required String label,
    int? count,
    bool hasDot = false,
    Color? dotColor,
  }) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () {
        setState(() => _statusFilter = key);
        _loadConversations();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (key == 'unread'
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFEFF6FF))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (key == 'unread'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2563EB))
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasDot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor ?? const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (key == 'unread'
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB))
                    : const Color(0xFF475569),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(ChatConversation conv) {
    final hasUnread = conv.unreadCount > 0;
    final bInfo = getBrandInfo(conv.brand);
    final assignedUserId =
        conv.assignedTo ?? conv.assignedAgentIds.firstOrNull;
    final assignedUser =
        assignedUserId != null ? _usersMap[assignedUserId] : null;

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
            // Avatar with circular platform badge on bottom right (matching Image 1)
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  avatarUrl: conv.customerAvatar,
                  name: conv.customerName,
                  radius: 24,
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

            // Content Area (3 Rows matching Image 1!)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Customer Name + Brand Badge (logo + name) + Time
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                conv.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Brand badge with circular logo & color
                            if (bInfo.logoUrl.isNotEmpty) ...[
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: Colors.transparent,
                                backgroundImage: NetworkImage(bInfo.logoUrl),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              bInfo.shortLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: bInfo.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(conv.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread ? workBlue : const Color(0xFF94A3B8),
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Last Message + Red unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessageText ?? 'เริ่มการสนทนา',
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
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conv.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Row 3: Assigned Agent Round Avatar (matching Image 1!)
                  Row(
                    children: [
                      if (assignedUser != null) ...[
                        UserAvatar(
                          avatarUrl: assignedUser.avatarUrl,
                          name: assignedUser.displayName,
                          radius: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          assignedUser.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else if (conv.assignedGroupName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_rounded,
                              size: 14, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          conv.assignedGroupName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () {
                            AssignAgentBottomSheet.show(
                              context,
                              conversation: conv,
                              onAssigned: (_) => _loadConversations(silent: true),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFFDBA74), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 11, color: Color(0xFFEA580C)),
                                SizedBox(width: 2),
                                Text(
                                  'รอจ่ายงาน',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFEA580C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
