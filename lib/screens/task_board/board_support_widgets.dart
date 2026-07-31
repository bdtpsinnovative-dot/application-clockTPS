part of '../task_board_page.dart';

class _TiltingDragCard extends StatelessWidget {
  const _TiltingDragCard({required this.dragXNotifier, required this.child});

  final ValueNotifier<double> dragXNotifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<double>(
      valueListenable: dragXNotifier,
      builder: (context, dragX, _) {
        final normX = ((dragX - (screenWidth / 2)) / (screenWidth / 2)).clamp(
          -1.0,
          1.0,
        );
        // Left side (normX < 0) tilts right (+0.20 rad = ~11.5 deg)
        // Right side (normX > 0) tilts left (-0.20 rad = ~-11.5 deg)
        final angle = -normX * 0.20;

        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: 1.06,
            child: Container(
              width: screenWidth * 0.80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x35000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

String resolveFullR2Url(String? url, String baseUrl) {
  if (url == null) return '';
  var trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('r2://')) {
    return trimmed.replaceFirst(
      'r2://',
      'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
    );
  }
  if (trimmed.startsWith('okpr2://')) {
    return trimmed.replaceFirst(
      'okpr2://',
      'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
    );
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('/')) {
    return '$baseUrl$trimmed';
  }
  return '$baseUrl/$trimmed';
}

class _BoardFilterBottomSheetContent extends StatefulWidget {
  final List<TaskListRecord> lists;
  final List<String> initialSelectedListIds;
  final String? initialSelectedStatus;
  final Function(List<String> listIds, String? status) onApply;

  const _BoardFilterBottomSheetContent({
    super.key,
    required this.lists,
    required this.initialSelectedListIds,
    this.initialSelectedStatus,
    required this.onApply,
  });

  @override
  State<_BoardFilterBottomSheetContent> createState() =>
      _BoardFilterBottomSheetContentState();
}

class _BoardFilterBottomSheetContentState
    extends State<_BoardFilterBottomSheetContent> {
  late List<String> _tempListIds;
  String? _tempStatus;

  @override
  void initState() {
    super.initState();
    _tempListIds = List.from(widget.initialSelectedListIds);
    _tempStatus = widget.initialSelectedStatus;
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
                      'กรองการ์ด',
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
              'หัวข้อรายการ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'เลือกหัวข้อที่ต้องการดู',
              style: TextStyle(fontSize: 11, color: workMuted),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _buildListOption(
                    label: 'ทุกหัวข้อ',
                    count: widget.lists.fold<int>(
                      0,
                      (total, list) => total + list.cards.length,
                    ),
                    isSelected: _tempListIds.isEmpty,
                    onTap: () {
                      setState(() => _tempListIds.clear());
                    },
                  ),
                  ...widget.lists.map((list) {
                    final isSelected = _tempListIds.contains(list.id);
                    return _buildListOption(
                      label: list.name,
                      count: list.cards.length,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _tempListIds = isSelected ? [] : [list.id];
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'สถานะการ์ด',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _buildFilterChip(
                  label: 'ทุกสถานะ',
                  isSelected: _tempStatus == null,
                  onTap: () => setState(() => _tempStatus = null),
                ),
                _buildFilterChip(
                  label: 'รอทำ',
                  isSelected: _tempStatus == 'pending',
                  onTap: () => setState(() => _tempStatus = 'pending'),
                  activeColor: const Color(0xFF2563EB),
                ),
                _buildFilterChip(
                  label: 'กำลังทำ',
                  isSelected: _tempStatus == 'in_progress',
                  onTap: () => setState(() => _tempStatus = 'in_progress'),
                  activeColor: const Color(0xFFEA580C),
                ),
                _buildFilterChip(
                  label: 'เสร็จสิ้น',
                  isSelected: _tempStatus == 'completed',
                  onTap: () => setState(() => _tempStatus = 'completed'),
                  activeColor: const Color(0xFF16A34A),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempListIds.clear();
                        _tempStatus = null;
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
                      widget.onApply(_tempListIds, _tempStatus);
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

  Widget _buildListOption({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: isSelected ? workBlue : const Color(0xFFCBD5E1),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? workBlue : workText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(fontSize: 10.5, color: workMuted),
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
          color: isSelected
              ? finalActiveColor.withValues(alpha: 0.1)
              : Colors.white,
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
