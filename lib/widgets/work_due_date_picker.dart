import 'package:flutter/material.dart';

import 'work_ui.dart';

DateTime workDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isWorkDatePast(DateTime value, {DateTime? now}) {
  return workDateOnly(value).isBefore(workDateOnly(now ?? DateTime.now()));
}

DateTime nextWorkMonday({DateTime? now}) {
  final today = workDateOnly(now ?? DateTime.now());
  var days = (DateTime.monday - today.weekday) % 7;
  if (days == 0) days = 7;
  return today.add(Duration(days: days));
}

Future<DateTime?> showWorkDueDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  String title = 'เลือกวันที่สิ้นสุด',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WorkDueDatePicker(initialDate: initialDate, title: title),
  );
}

class _WorkDueDatePicker extends StatefulWidget {
  const _WorkDueDatePicker({this.initialDate, required this.title});

  final DateTime? initialDate;
  final String title;

  @override
  State<_WorkDueDatePicker> createState() => _WorkDueDatePickerState();
}

class _WorkDueDatePickerState extends State<_WorkDueDatePicker> {
  static const _months = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  static const _weekdays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  late DateTime _selected;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selected = workDateOnly(widget.initialDate ?? DateTime.now());
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  void _select(DateTime date) {
    setState(() {
      _selected = workDateOnly(date);
      _visibleMonth = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = workDateOnly(DateTime.now());
    final tomorrow = now.add(const Duration(days: 1));
    final monday = nextWorkMonday(now: now);
    final selectedIsPast = isWorkDatePast(_selected, now: now);
    final firstWeekday = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    ).weekday;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: TextStyle(
                color: workText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickDateButton(
                  label: 'วันนี้',
                  selected: _selected == now,
                  onTap: () => _select(now),
                ),
                const SizedBox(width: 7),
                _QuickDateButton(
                  label: 'พรุ่งนี้',
                  selected: _selected == tomorrow,
                  onTap: () => _select(tomorrow),
                ),
                const SizedBox(width: 7),
                _QuickDateButton(
                  label: 'จันทร์หน้า',
                  selected: _selected == monday,
                  onTap: () => _select(monday),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'เดือนก่อนหน้า',
                  onPressed: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  }),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year + 543}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: workText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'เดือนถัดไป',
                  onPressed: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  }),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: _weekdays
                  .map(
                    (label) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: workMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 42,
              ),
              itemCount: firstWeekday - 1 + daysInMonth,
              itemBuilder: (context, index) {
                final day = index - (firstWeekday - 2);
                if (day < 1) return const SizedBox.shrink();
                final date = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month,
                  day,
                );
                final isSelected = date == _selected;
                final isToday = date == now;
                final isPast = date.isBefore(now);
                final selectedColor = isPast
                    ? const Color(0xFFDC2626)
                    : workBlue;

                return InkWell(
                  onTap: () => _select(date),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? selectedColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: isToday && !isSelected
                          ? Border.all(color: workBlue)
                          : null,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isPast
                            ? const Color(0xFF94A3B8)
                            : workText,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (selectedIsPast) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'วันที่เลือกผ่านมาแล้ว แต่ยังสามารถบันทึกได้',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: FilledButton.styleFrom(
                  backgroundColor: selectedIsPast
                      ? const Color(0xFFDC2626)
                      : workBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text(
                  'เลือกวันที่นี้',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDateButton extends StatelessWidget {
  const _QuickDateButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? workBlue : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? workBlue : workText,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
