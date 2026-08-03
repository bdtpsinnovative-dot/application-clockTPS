part of '../admin_tasks_page.dart';

// ─── Create Task Modal Sheet widget ──────────────────────────────
class _CreateTaskModal extends StatefulWidget {
  const _CreateTaskModal({
    required this.users,
    required this.brands,
    required this.categories,
    required this.onSubmit,
  });

  final List<AppUser> users;
  final List<BrandRecord> brands;
  final List<TaskCategoryRecord> categories;
  final Function(
    String title,
    String desc,
    List<String> assignees,
    DateTime due,
    String? brand,
    String? category,
    String? priority,
    String? status,
    String initialListName,
  ) onSubmit;

  @override
  State<_CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<_CreateTaskModal> {
  String? _formBrand;
  String? _formCategory;
  final List<String> _formAssignees = [];
  String _formTitle = '';
  String _formDesc = '';
  DateTime _formDue = DateTime.now().add(const Duration(days: 1));
  String? _formPriority = 'medium';
  String? _formStatus = 'pending';
  String _formInitialBoardName = '';
  bool _showAdvanced = false;
  bool _formLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.add_task_rounded, color: workBlue, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'มอบหมายงานใหม่',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: workText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: workMuted,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // ── 1. Title (ชื่องาน) ──
            _fieldLabel('ชื่องาน *', Icons.title_rounded),
            const SizedBox(height: 4),
            TextField(
              decoration: _inputDeco('กรอกชื่องาน / หัวข้อ'),
              onChanged: (v) => _formTitle = v,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),

            // ── 2. Description (รายละเอียดงาน) ──
            _fieldLabel('รายละเอียดงาน', Icons.notes_rounded),
            const SizedBox(height: 4),
            TextField(
              maxLines: 2,
              decoration: _inputDeco('อธิบายรายละเอียดงาน...'),
              onChanged: (v) => _formDesc = v,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),

            // ── 3. Assignees (ผู้รับผิดชอบ) ──
            _fieldLabel(
              'ผู้รับผิดชอบ * (เลือกได้มากกว่า 1 คน)',
              Icons.people_outline_rounded,
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.users.length,
                itemBuilder: (context, i) {
                  final u = widget.users[i];
                  final isSelected = _formAssignees.contains(u.id);
                  final resolvedAvatar =
                      u.avatarUrl != null && u.avatarUrl!.trim().isNotEmpty
                      ? (u.avatarUrl!.startsWith('r2://')
                            ? u.avatarUrl!.replaceFirst(
                                'r2://',
                                'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
                              )
                            : u.avatarUrl)
                      : null;

                  final displayName = u.nickname.trim().isNotEmpty ? u.nickname : u.firstName;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _formAssignees.remove(u.id);
                        } else {
                          _formAssignees.add(u.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? workBlue : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  backgroundImage: resolvedAvatar != null
                                      ? NetworkImage(resolvedAvatar)
                                      : null,
                                  radius: 16,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  child: resolvedAvatar == null
                                      ? Text(
                                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: workText,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(1),
                                    decoration: const BoxDecoration(
                                      color: workBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? workBlue : workText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Toggle Advanced options (วงกลมที่มี บวก) ──
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: workBlue.withValues(alpha: 0.08),
                      border: Border.all(color: workBlue.withValues(alpha: 0.25)),
                    ),
                    child: Icon(
                      _showAdvanced ? Icons.remove : Icons.add,
                      color: workBlue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // ── Advanced Optional Fields (วันส่ง, แบรนด์, หมวดหมู่, ความสำคัญ, สถานะ, ชื่อบอร์ด) ──
            if (_showAdvanced) ...[
              // Date picker
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('กำหนดส่ง *', Icons.calendar_month_rounded),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final p = await showWorkDueDatePicker(
                        context,
                        initialDate: _formDue,
                      );
                      if (p != null) setState(() => _formDue = p);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isWorkDatePast(_formDue)
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: isWorkDatePast(_formDue)
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('dd MMMM yyyy', 'th').format(_formDue),
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isWorkDatePast(_formDue)
                                    ? const Color(0xFFDC2626)
                                    : workText,
                                fontWeight: isWorkDatePast(_formDue)
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_month_rounded,
                            color: isWorkDatePast(_formDue)
                                ? const Color(0xFFDC2626)
                                : workBlue,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isWorkDatePast(_formDue)) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'วันที่กำหนดส่งผ่านมาแล้ว แต่ยังสามารถสร้างงานได้',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Brand + Category Row
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String?>(
                      label: 'แบรนด์',
                      icon: Icons.label_outline_rounded,
                      value: _formBrand,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— ไม่ระบุ —'),
                        ),
                        ...widget.brands.map(
                          (b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(
                              b.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _formBrand = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown<String?>(
                      label: 'หมวดหมู่',
                      icon: Icons.folder_outlined,
                      value: _formCategory,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— ไม่ระบุ —'),
                        ),
                        ...widget.categories.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _formCategory = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Priority + Status Row
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String?>(
                      label: 'ความสำคัญ',
                      icon: Icons.priority_high_rounded,
                      value: _formPriority,
                      items: const <DropdownMenuItem<String?>>[
                        DropdownMenuItem(
                          value: 'low',
                          child: Text('ต่ำ', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('ปานกลาง', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('สูง', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('ด่วนมาก', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _formPriority = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown<String?>(
                      label: 'สถานะงานเริ่มต้น',
                      icon: Icons.hourglass_empty_rounded,
                      value: _formStatus,
                      items: const <DropdownMenuItem<String?>>[
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('รอทำ', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('กำลังทำ', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'in_review',
                          child: Text('รอตรวจ', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('เสร็จสิ้น', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _formStatus = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Initial Board List Name
              _fieldLabel('บอร์ดงานเริ่มต้น', Icons.splitscreen_rounded),
              const SizedBox(height: 4),
              TextField(
                decoration: _inputDeco('ระบุชื่อบอร์ดงานเริ่มต้น (เช่น งานหลัก)'),
                onChanged: (v) => _formInitialBoardName = v,
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // ── Submit Button ──
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [workBlue, workSky],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3F2563EB),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _formLoading
                    ? null
                    : () async {
                        if (_formTitle.trim().isEmpty ||
                            _formAssignees.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'กรุณากรอกชื่องานและเลือกผู้รับผิดชอบอย่างน้อย 1 คน',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _formLoading = true);
                        try {
                          await widget.onSubmit(
                            _formTitle,
                            _formDesc,
                            _formAssignees,
                            _formDue,
                            _formBrand,
                            _formCategory,
                            _formPriority,
                            _formStatus,
                            _formInitialBoardName,
                          );
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _formLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _formLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'มอบหมายงาน',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, icon),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          decoration: _inputDeco('').copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: workText),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: workBlue),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: workMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: workMuted),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: workBlue, width: 1.2),
      ),
    );
  }
}
