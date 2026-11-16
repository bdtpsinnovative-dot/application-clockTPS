import 'package:flutter/material.dart';
import '../../widgets/user_avatar.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class AssignAgentBottomSheet extends StatefulWidget {
  const AssignAgentBottomSheet({
    super.key,
    required this.conversation,
    required this.onAssigned,
  });

  final ChatConversation conversation;
  final ValueChanged<ChatConversation> onAssigned;

  static Future<void> show(
    BuildContext context, {
    required ChatConversation conversation,
    required ValueChanged<ChatConversation> onAssigned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignAgentBottomSheet(
        conversation: conversation,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AssignAgentBottomSheet> createState() => _AssignAgentBottomSheetState();
}

class _AssignAgentBottomSheetState extends State<AssignAgentBottomSheet> {
  List<ChatAgentUser> _users = [];
  List<ChatCareGroup> _groups = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uList = await ChatService.instance.fetchActiveUsers();
    final gList = await ChatService.instance.fetchCareGroups();
    if (!mounted) return;
    setState(() {
      _users = uList;
      _groups = gList;
      _loading = false;
    });
  }

  Future<void> _handleClear() async {
    final success = await ChatService.instance.clearAssignment(
      widget.conversation.id,
      existingMetadata: widget.conversation.metadata,
    );
    if (!mounted) return;
    if (success) {
      final updated = widget.conversation.copyWith(
        assignedTo: '',
        assignedToName: '',
        metadata: {
          ...widget.conversation.metadata,
          'assigned_agent_ids': [],
        }..remove('assigned_group_id')..remove('assigned_group_name'),
      );
      widget.onAssigned(updated);
      Navigator.pop(context);
    }
  }

  Future<void> _handleAssignUser(ChatAgentUser user) async {
    final success = await ChatService.instance.assignAgent(
      widget.conversation.id,
      agentId: user.id,
      agentName: user.displayName,
      existingMetadata: widget.conversation.metadata,
    );
    if (!mounted) return;
    if (success) {
      final updated = widget.conversation.copyWith(
        assignedTo: user.id,
        assignedToName: user.displayName,
        metadata: {
          ...widget.conversation.metadata,
          'assigned_agent_ids': [user.id],
        }..remove('assigned_group_id')..remove('assigned_group_name'),
      );
      widget.onAssigned(updated);
      Navigator.pop(context);
    }
  }

  Future<void> _handleAssignGroup(ChatCareGroup group) async {
    final success = await ChatService.instance.assignCareGroup(
      widget.conversation.id,
      group,
      existingMetadata: widget.conversation.metadata,
    );
    if (!mounted) return;
    if (success) {
      final updated = widget.conversation.copyWith(
        assignedTo: group.agentIds.isNotEmpty ? group.agentIds.first : '',
        assignedToName: group.name,
        metadata: {
          ...widget.conversation.metadata,
          'assigned_agent_ids': group.agentIds,
          'assigned_group_id': group.id,
          'assigned_group_name': group.name,
        },
      );
      widget.onAssigned(updated);
      Navigator.pop(context);
    }
  }

  Future<void> _handleMultiAgentDialog() async {
    final selectedIds = Set<String>.from(widget.conversation.assignedAgentIds);
    final groupNameCtrl = TextEditingController(
      text: widget.conversation.assignedGroupName ?? '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'เพิ่มหลายคน / ตั้งชื่อกลุ่ม',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: Column(
              children: [
                TextField(
                  controller: groupNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อกลุ่ม / ทีม (เว้นว่างได้)',
                    hintText: 'เช่น ทีมดูแลลูกค้า TERRA',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'เลือกผู้ดูแลที่ร่วมดูแลลูกค้าท่านนี้:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (ctx, idx) {
                      final u = _users[idx];
                      final isChecked = selectedIds.contains(u.id);
                      return CheckboxListTile(
                        value: isChecked,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        secondary: UserAvatar(
                          avatarUrl: u.avatarUrl,
                          name: u.displayName,
                          radius: 14,
                        ),
                        title: Text(u.fullName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          u.department.isNotEmpty ? u.department : u.role,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedIds.add(u.id);
                            } else {
                              selectedIds.remove(u.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: selectedIds.isNotEmpty ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('บันทึกการมอบหมาย'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selectedIds.isNotEmpty) {
      final grpName = groupNameCtrl.text.trim().isNotEmpty
          ? groupNameCtrl.text.trim()
          : 'ทีมดูแล (${selectedIds.length} คน)';
      final primaryAgentId = selectedIds.first;
      final primaryAgent =
          _users.firstWhere((u) => u.id == primaryAgentId, orElse: () => _users.first);

      final meta = Map<String, dynamic>.from(widget.conversation.metadata);
      meta['assigned_agent_ids'] = selectedIds.toList();
      meta['assigned_group_name'] = grpName;
      meta['assigned_at'] = DateTime.now().toUtc().toIso8601String();

      final res = await ChatService.instance.assignAgent(
        widget.conversation.id,
        agentId: primaryAgentId,
        agentName: primaryAgent.displayName,
        existingMetadata: meta,
      );

      if (!mounted) return;
      if (res) {
        final updated = widget.conversation.copyWith(
          assignedTo: primaryAgentId,
          assignedToName: grpName,
          metadata: meta,
        );
        widget.onAssigned(updated);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAssignedTo = widget.conversation.assignedTo;
    final currentGroupId = widget.conversation.assignedGroupId;

    final filteredUsers = _users.where((u) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.department.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'มอบหมายผู้ดูแลลูกค้า',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อเซลส์/ผู้ดูแล...',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // Clear assignment item
            InkWell(
              onTap: _handleClear,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                color: (currentAssignedTo == null || currentAssignedTo.isEmpty)
                    ? const Color(0xFFFEF2F2)
                    : Colors.transparent,
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined,
                        color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'ยกเลิกผู้ดูแล (ไม่มีผู้ดูแล)',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (currentAssignedTo == null || currentAssignedTo.isEmpty)
                      const Icon(Icons.check_rounded,
                          color: Color(0xFFDC2626), size: 18),
                  ],
                ),
              ),
            ),

            // Multi-agent / Create group trigger (Matches Screenshot 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: InkWell(
                onTap: _handleMultiAgentDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.group_add_rounded,
                          color: Color(0xFF2563EB), size: 18),
                      SizedBox(width: 10),
                      Text(
                        'เพิ่มหลายคน / ตั้งชื่อกลุ่ม...',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // List of Groups and Agents
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        // Care Groups Section
                        if (_groups.isNotEmpty && _searchQuery.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
                            child: Text(
                              'กลุ่มแชท',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          ..._groups.map((grp) {
                            final isSelected = currentGroupId == grp.id;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.group_rounded,
                                    color: Color(0xFF2563EB), size: 18),
                              ),
                              title: Text(
                                '${grp.name} (${grp.agentIds.length})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Color(0xFF2563EB), size: 18)
                                  : null,
                              onTap: () => _handleAssignGroup(grp),
                            );
                          }),
                          const Divider(height: 12),
                        ],

                        // Individual Staff Section
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
                          child: Text(
                            '👤 มอบหมายรายบุคคล (เซลส์/ผู้ดูแล)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        if (filteredUsers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'ไม่พบรายชื่อที่ค้นหา',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ...filteredUsers.map((user) {
                            final isSelected = currentAssignedTo == user.id &&
                                (currentGroupId == null ||
                                    currentGroupId.isEmpty);

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 2),
                              leading: UserAvatar(
                                avatarUrl: user.avatarUrl,
                                name: user.displayName,
                                radius: 18,
                              ),
                              title: Text(
                                user.fullName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                user.department.isNotEmpty
                                    ? user.department
                                    : user.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Color(0xFF2563EB), size: 20)
                                  : null,
                              onTap: () => _handleAssignUser(user),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
