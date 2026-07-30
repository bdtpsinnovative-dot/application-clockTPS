part of '../admin_tasks_page.dart';

class _FilterBottomSheetContent extends StatefulWidget {
  final List<BrandRecord> brands;
  final List<TaskCategoryRecord> categories;
  final String? initialBrandId;
  final String? initialCategoryId;
  final Function(String? brandId, String? categoryId) onApply;

  const _FilterBottomSheetContent({
    super.key,
    required this.brands,
    required this.categories,
    this.initialBrandId,
    this.initialCategoryId,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheetContent> createState() =>
      _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<_FilterBottomSheetContent> {
  String? _tempBrandId;
  String? _tempCategoryId;

  @override
  void initState() {
    super.initState();
    _tempBrandId = widget.initialBrandId;
    _tempCategoryId = widget.initialCategoryId;
  }

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: workBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ตัวกรองบอร์ดงาน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: workText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: workMuted),
                ),
              ],
            ),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            const Text(
              'แบรนด์ (Brand)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempBrandId == null,
                  onTap: () => setState(() => _tempBrandId = null),
                ),
                ...widget.brands.map(
                  (b) => _buildFilterChip(
                    label: b.name,
                    isSelected: _tempBrandId == b.id,
                    onTap: () => setState(() => _tempBrandId = b.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'หมวดหมู่ (Category)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempCategoryId == null,
                  onTap: () => setState(() => _tempCategoryId = null),
                ),
                ...widget.categories.map(
                  (c) => _buildFilterChip(
                    label: c.name,
                    isSelected: _tempCategoryId == c.id,
                    onTap: () => setState(() => _tempCategoryId = c.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempBrandId = null;
                        _tempCategoryId = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: workMuted,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'ล้างตัวกรอง',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_tempBrandId, _tempCategoryId);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: workBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ใช้ตัวกรอง',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final finalActiveColor = activeColor ?? workBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? finalActiveColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? finalActiveColor : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? finalActiveColor : workText,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
