part of '../admin_tasks_page.dart';

class _InitialTaskBoard {
  _InitialTaskBoard();

  String name = '';
  String description = '';
  DateTime? dueDate;
  String priority = 'medium';
}

typedef _CreateTaskSubmit =
    Future<void> Function(
      String title,
      String description,
      List<String> assigneeIds,
      DateTime dueDate,
      String? brandId,
      String? categoryId,
      String priority,
      String status,
      List<_InitialTaskBoard> boards,
    );

class _CreateTaskModal extends StatefulWidget {
  const _CreateTaskModal({
    required this.users,
    required this.brands,
    required this.categories,
    required this.onSubmit,
    this.currentUser,
    this.initialTask,
  });

  final List<AppUser> users;
  final List<BrandRecord> brands;
  final List<TaskCategoryRecord> categories;
  final AppUser? currentUser;
  final TaskRecord? initialTask;
  final _CreateTaskSubmit onSubmit;

  @override
  State<_CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<_CreateTaskModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _brandId;
  String? _categoryId;
  final List<String> _assigneeIds = [];
  final Set<String> _autoBrandAssigneeIds = {};
  final List<_InitialTaskBoard> _boards = [];
  String _title = '';
  String _description = '';
  DateTime _dueDate = DateTime.now();
  String _priority = 'low';
  String _status = 'pending';
  bool _showAssigneePicker = false;
  bool _submitting = false;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _title = task?.title ?? '';
    _description = task?.description ?? '';
    _titleController = TextEditingController(text: _title);
    _descriptionController = TextEditingController(text: _description);
    _brandId = task?.brandId;
    _categoryId = task?.categoryId;
    _dueDate = task?.dueDate ?? DateTime.now();
    _priority = task?.priority ?? 'low';
    _status = task?.status ?? 'pending';

    if (task != null) {
      _assigneeIds.addAll(
        task.assigneeIds.isNotEmpty
            ? task.assigneeIds
            : [if (task.assignedTo.isNotEmpty) task.assignedTo],
      );
    } else {
      final currentUserId = widget.currentUser?.id.trim() ?? '';
      if (currentUserId.isNotEmpty) _assigneeIds.add(currentUserId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('ชื่องาน *'),
                    const SizedBox(height: 6),
                    TextField(
                      key: Key(
                        _isEditing ? 'edit-task-title' : 'create-task-title',
                      ),
                      controller: _titleController,
                      decoration: _inputDecoration(
                        'เช่น ทำรายงานสรุปยอดขายประจำสัปดาห์...',
                      ),
                      onChanged: (value) => _title = value,
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(
                      'รายละเอียดเพิ่มเติม',
                      icon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: Key(
                        _isEditing
                            ? 'edit-task-description'
                            : 'create-task-description',
                      ),
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'รายละเอียดเพิ่มเติมของงาน...',
                      ),
                      onChanged: (value) => _description = value,
                    ),
                    const SizedBox(height: 16),
                    _buildAssignees(),
                    const SizedBox(height: 16),
                    _buildTaskMetadata(),
                    const SizedBox(height: 16),
                    _buildPriorityAndStatus(),
                    if (!_isEditing) ...[
                      const SizedBox(height: 16),
                      _buildBoards(),
                    ],
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing ? 'แก้ไขงานมอบหมาย' : 'มอบหมายงานใหม่',
              style: const TextStyle(
                color: workText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            key: Key(_isEditing ? 'close-edit-task' : 'close-create-task'),
            onPressed: _submitting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignees() {
    final selectedUsers = widget.users
        .where((user) => _assigneeIds.contains(user.id))
        .toList();
    final candidates = widget.users
        .where((user) => !_assigneeIds.contains(user.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('ผู้รับผิดชอบ', icon: Icons.person_outline_rounded),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final user in selectedUsers) _selectedAssignee(user),
            InkWell(
              key: const Key('toggle-assignee-picker'),
              onTap: () =>
                  setState(() => _showAssigneePicker = !_showAssigneePicker),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: _showAssigneePicker
                        ? workBlue
                        : const Color(0xFFB9C8DC),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _showAssigneePicker ? Icons.remove : Icons.add,
                  color: workBlue,
                  size: 23,
                ),
              ),
            ),
          ],
        ),
        if (_showAssigneePicker) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('assignee-picker'),
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 190),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFD8E1EE)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: candidates.isEmpty
                ? const Center(
                    child: Text(
                      'เลือกผู้รับผิดชอบครบทุกคนแล้ว',
                      style: TextStyle(color: workMuted, fontSize: 12),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final user in candidates) _assigneeCandidate(user),
                      ],
                    ),
                  ),
          ),
        ],
        ..._buildBrandResponsibilityGroups(),
      ],
    );
  }

  Widget _selectedAssignee(AppUser user) {
    final locked =
        !_isEditing &&
        (user.id == widget.currentUser?.id ||
            _autoBrandAssigneeIds.contains(user.id));
    return Tooltip(
      message: _userDisplayName(user),
      child: InkWell(
        onTap: locked
            ? null
            : () => setState(() => _assigneeIds.remove(user.id)),
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              avatarUrl: user.avatarUrl,
              name: _userDisplayName(user),
              radius: 18,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: locked ? const Color(0xFF8B5CF6) : workBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  locked ? Icons.lock_rounded : Icons.check_rounded,
                  color: Colors.white,
                  size: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assigneeCandidate(AppUser user) {
    return InkWell(
      key: Key('assignee-${user.id}'),
      onTap: () => setState(() => _assigneeIds.add(user.id)),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD8E1EE)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: user.avatarUrl,
              name: _userDisplayName(user),
              radius: 14,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                _userDisplayName(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: workText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskMetadata() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _dateField()),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdown<String?>(
            label: 'แบรนด์',
            icon: Icons.sell_outlined,
            value: _brandId,
            items: [
              const DropdownMenuItem(value: null, child: Text('เลือก')),
              for (final brand in widget.brands)
                DropdownMenuItem(
                  value: brand.id,
                  child: Text(
                    brand.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _changeBrand,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdown<String?>(
            label: 'หมวดหมู่',
            icon: Icons.folder_outlined,
            value: _categoryId,
            items: [
              const DropdownMenuItem(value: null, child: Text('เลือก')),
              for (final category in widget.categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('วันครบกำหนด *', icon: Icons.calendar_month_outlined),
        const SizedBox(height: 6),
        InkWell(
          key: const Key('task-due-date'),
          onTap: () async {
            final picked = await showWorkDueDatePicker(
              context,
              initialDate: _dueDate,
            );
            if (picked != null && mounted) setState(() => _dueDate = picked);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: _fieldBoxDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_dueDate),
                      style: const TextStyle(color: workText, fontSize: 12),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_rounded, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityAndStatus() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _dropdown<String>(
            label: 'ความสำคัญ (Priority)',
            icon: Icons.local_fire_department_outlined,
            value: _priority,
            items: const [
              DropdownMenuItem(value: 'low', child: Text('🌱 งานไม่รีบ (Low)')),
              DropdownMenuItem(
                value: 'medium',
                child: Text('⚡ ปานกลาง (Medium)'),
              ),
              DropdownMenuItem(value: 'high', child: Text('🔥 สำคัญ (High)')),
              DropdownMenuItem(
                value: 'urgent',
                child: Text('🚨 ด่วนมาก (Urgent)'),
              ),
            ],
            onChanged: (value) => setState(() => _priority = value ?? 'low'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dropdown<String>(
            label: 'สถานะ (Status)',
            icon: Icons.check_circle_outline_rounded,
            value: _status,
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('รอทำ (Pending)')),
              DropdownMenuItem(value: 'in_progress', child: Text('กำลังทำ')),
              DropdownMenuItem(value: 'in_review', child: Text('รอตรวจ')),
              DropdownMenuItem(value: 'completed', child: Text('เสร็จสิ้น')),
            ],
            onChanged: (value) => setState(() => _status = value ?? 'pending'),
          ),
        ),
      ],
    );
  }

  Widget _buildBoards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _fieldLabel(
                'บอร์ดงานเริ่มต้น',
                icon: Icons.grid_view_rounded,
              ),
            ),
            TextButton.icon(
              key: const Key('add-initial-board'),
              onPressed: () => setState(() => _boards.add(_InitialTaskBoard())),
              style: TextButton.styleFrom(
                foregroundColor: workBlue,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'เพิ่มบอร์ดงาน',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const Divider(height: 12, color: Color(0xFFE2E8F0)),
        for (var index = 0; index < _boards.length; index++) ...[
          _boardEditor(index, _boards[index]),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _boardEditor(int index, _InitialTaskBoard board) {
    return Container(
      key: Key('initial-board-$index'),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFD8E1EE)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: _inputDecoration('ชื่อบอร์ดงานที่ ${index + 1}'),
                  onChanged: (value) => board.name = value,
                ),
              ),
              if (_boards.length > 1) ...[
                const SizedBox(width: 6),
                IconButton(
                  key: Key('remove-initial-board-$index'),
                  tooltip: 'ลบบอร์ดงาน',
                  onPressed: () => setState(() => _boards.removeAt(index)),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration('รายละเอียดเพิ่มเติมของบอร์ดงาน...'),
            onChanged: (value) => board.description = value,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showWorkDueDatePicker(
                      context,
                      initialDate: board.dueDate ?? _dueDate,
                    );
                    if (picked != null && mounted) {
                      setState(() => board.dueDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: _fieldBoxDecoration(),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            board.dueDate == null
                                ? 'วว/ดด/ปปปป'
                                : DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(board.dueDate!),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: board.dueDate == null
                                  ? workMuted
                                  : workText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: board.priority,
                  isExpanded: true,
                  decoration: _compactDropdownDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('🌱 งานไม่รีบ (Low)'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('⚡ ปานกลาง (Medium)'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('🔥 สำคัญ (High)'),
                    ),
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text('🚨 ด่วนมาก (Urgent)'),
                    ),
                  ],
                  onChanged: (value) => board.priority = value ?? 'medium',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: workText,
                minimumSize: const Size(0, 44),
              ),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: Key(_isEditing ? 'submit-edit-task' : 'submit-create-task'),
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: workBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'บันทึกข้อมูล' : 'สร้างงาน',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final validBoards = _boards
        .where((board) => board.name.trim().isNotEmpty)
        .toList();
    if (_title.trim().isEmpty) {
      _showError('กรุณากรอกชื่องาน');
      return;
    }
    if (_assigneeIds.isEmpty) {
      _showError('กรุณาเลือกผู้รับผิดชอบอย่างน้อย 1 คน');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _title.trim(),
        _description.trim(),
        List<String>.unmodifiable(_assigneeIds),
        _dueDate,
        _brandId,
        _categoryId,
        _priority,
        _status,
        validBoards,
      );
      if (mounted) Navigator.pop(context, _isEditing ? true : null);
    } catch (error) {
      if (mounted) _showError('เกิดข้อผิดพลาด: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, icon: icon),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: _compactDropdownDecoration(),
          items: items,
          onChanged: onChanged,
          style: const TextStyle(color: workText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: const Color(0xFF8BA0BA)),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: workText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: workMuted, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: _inputBorder(),
      enabledBorder: _inputBorder(),
      focusedBorder: _inputBorder(workBlue, 1.3),
    );
  }

  InputDecoration _compactDropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      border: _inputBorder(),
      enabledBorder: _inputBorder(),
      focusedBorder: _inputBorder(workBlue, 1.3),
    );
  }

  OutlineInputBorder _inputBorder([
    Color color = const Color(0xFFD8E1EE),
    double width = 1,
  ]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  BoxDecoration _fieldBoxDecoration() {
    return BoxDecoration(
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: const Color(0xFFD8E1EE)),
      borderRadius: BorderRadius.circular(10),
    );
  }

  String _userDisplayName(AppUser user) {
    if (user.nickname.trim().isNotEmpty) return user.nickname.trim();
    if (user.firstName.trim().isNotEmpty) return user.firstName.trim();
    return user.email;
  }

  void _changeBrand(String? brandId) {
    if (_isEditing) {
      setState(() => _brandId = brandId);
      return;
    }
    final manualAssignees = _assigneeIds
        .where((id) => !_autoBrandAssigneeIds.contains(id))
        .toSet();
    final brand = widget.brands.where((item) => item.id == brandId).firstOrNull;
    final autoAssignees = brand == null
        ? <String>{}
        : _autoAssigneeIdsForBrand(brand);
    setState(() {
      _brandId = brandId;
      _autoBrandAssigneeIds
        ..clear()
        ..addAll(autoAssignees);
      _assigneeIds
        ..clear()
        ..addAll(manualAssignees)
        ..addAll(autoAssignees);
    });
  }

  Set<String> _autoAssigneeIdsForBrand(BrandRecord brand) {
    final groups = _visibleResponsibilityGroups(brand);
    final currentUserId = widget.currentUser?.id;
    String? currentTeamType;
    for (final entry in groups.reversed) {
      if (currentUserId != null &&
          entry.value.any((user) => user.id == currentUserId)) {
        currentTeamType = entry.key;
        break;
      }
    }
    currentTeamType ??= _responsibilityTypeForUser(widget.currentUser);

    return groups
        .where((entry) => entry.key != currentTeamType)
        .expand((entry) => entry.value)
        .map((user) => user.id)
        .toSet();
  }

  List<MapEntry<String, List<AppUser>>> _visibleResponsibilityGroups(
    BrandRecord brand,
  ) {
    const types = ['bd', 'mkt', 'graphic'];
    final usersById = {for (final user in widget.users) user.id: user};
    final groups = <MapEntry<String, List<AppUser>>>[];
    for (final type in types) {
      final userIds = brand.hasTypedResponsibilities
          ? brand.responsibilities
                .where((item) => item.type == type)
                .map((item) => item.userId)
          : type == 'bd'
          ? brand.responsibleUserIds
          : const <String>[];
      final users = userIds
          .map((id) => usersById[id])
          .whereType<AppUser>()
          .where(
            (user) =>
                user.status == 'active' &&
                (brand.hasTypedResponsibilities ||
                    user.position.trim().toLowerCase() == 'bd'),
          )
          .toList(growable: false);
      groups.add(MapEntry(type, users));
    }

    final currentUserId = widget.currentUser?.id;
    final teamType = _responsibilityTypeForUser(widget.currentUser);
    final teamIndex = teamType == null ? -1 : types.indexOf(teamType);
    var mappedIndex = -1;
    if (currentUserId != null) {
      for (var index = 0; index < groups.length; index++) {
        if (groups[index].value.any((user) => user.id == currentUserId)) {
          mappedIndex = index;
        }
      }
    }
    final currentIndex = teamIndex > mappedIndex ? teamIndex : mappedIndex;
    return groups.take(currentIndex < 0 ? 1 : currentIndex + 1).toList();
  }

  String? _responsibilityTypeForUser(AppUser? user) {
    if (user == null) return null;
    final teamKey = '${user.position}${user.department}'
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z]'), '');
    if (teamKey == 'bd' || teamKey.contains('businessdevelop')) return 'bd';
    if (teamKey == 'mkt' || teamKey.contains('marketing')) return 'mkt';
    if (teamKey == 'gp' || teamKey.contains('graphic')) return 'graphic';
    return null;
  }

  List<Widget> _buildBrandResponsibilityGroups() {
    final brand = widget.brands
        .where((item) => item.id == _brandId)
        .firstOrNull;
    if (brand == null) return const [];
    final groups = _visibleResponsibilityGroups(
      brand,
    ).where((entry) => entry.value.isNotEmpty).toList();
    if (groups.isEmpty) return const [];
    const labels = {'bd': 'BD', 'mkt': 'MKT', 'graphic': 'Graphic'};

    return [
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFD8E1EE)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ทีมผู้รับผิดชอบแบรนด์',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${labels[group.key]}: ${group.value.map(_userDisplayName).join(', ')}',
                  style: const TextStyle(color: workText, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
