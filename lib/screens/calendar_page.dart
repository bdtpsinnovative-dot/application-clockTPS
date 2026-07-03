import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';

class WorkCalendarPage extends StatefulWidget {
  const WorkCalendarPage({
    super.key,
    required this.service,
    required this.onMenu,
    required this.onOpenRequests,
  });

  final AuthFlowService service;
  final VoidCallback onMenu;
  final VoidCallback onOpenRequests;

  @override
  State<WorkCalendarPage> createState() => _WorkCalendarPageState();
}

class _WorkCalendarPageState extends State<WorkCalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  List<AttendanceRecord> _attendance = const [];
  List<HolidayRecord> _holidays = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.getAttendanceHistory(_month.year, _month.month),
        widget.service.getHolidays(_month.year),
      ]);
      if (mounted) {
        setState(() {
          _attendance = results[0] as List<AttendanceRecord>;
          _holidays = results[1] as List<HolidayRecord>;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = DateTime(_month.year, _month.month, 1);
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final cells = List<DateTime?>.generate(
      leading + daysInMonth,
      (index) => index < leading
          ? null
          : DateTime(_month.year, _month.month, index - leading + 1),
    );
    final selectedHoliday = _holidayAt(_selected);
    final selectedAttendance = _attendanceAt(_selected);

    return ColoredBox(
      color: workBackground,
      child: RefreshIndicator(
        onRefresh: _loadMonth,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            WorkHeader(
              title: 'ปฏิทินตารางงาน',
              subtitle: 'การลงเวลาและวันหยุด',
              onMenu: widget.onMenu,
              bottomPadding: 68,
            ),
            Transform.translate(
              offset: const Offset(0, -46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    WorkCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _changeMonth(-1),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  DateFormat('MMMM yyyy').format(_month),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _changeMonth(1),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                          if (_loading)
                            const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              _Weekday('Mo'),
                              _Weekday('Tu'),
                              _Weekday('We'),
                              _Weekday('Th'),
                              _Weekday('Fr'),
                              _Weekday('Sa'),
                              _Weekday('Su'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisExtent: 42,
                                ),
                            itemCount: cells.length,
                            itemBuilder: (context, index) {
                              final date = cells[index];
                              if (date == null) return const SizedBox.shrink();
                              final selected = _sameDate(date, _selected);
                              final attendance = _attendanceAt(date);
                              final holiday = _holidayAt(date);
                              return InkWell(
                                onTap: () => setState(() => _selected = date),
                                borderRadius: BorderRadius.circular(99),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? workText
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : workText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (attendance != null || holiday != null)
                                      Positioned(
                                        bottom: 1,
                                        child: Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: holiday != null
                                                ? const Color(0xFFEF4444)
                                                : attendance!.status == 'late'
                                                ? const Color(0xFFF59E0B)
                                                : attendance.status == 'offsite'
                                                ? const Color(0xFF3B82F6)
                                                : (attendance.status == 'no_record' || attendance.status == 'absent')
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF22C55E),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    WorkCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_calendar_rounded,
                              color: workBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedHoliday?.name ??
                                      (selectedAttendance != null
                                          ? 'มีบันทึกการลงเวลา'
                                          : 'ไม่มีกำหนดการ'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'EEEE, d MMM yyyy',
                                  ).format(_selected),
                                  style: const TextStyle(
                                    color: workMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onOpenRequests,
                            child: const Text('ยื่นคำขอ'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AttendanceRecord? _attendanceAt(DateTime date) {
    for (final item in _attendance) {
      if (_sameDate(item.date, date)) return item;
    }
    return null;
  }

  HolidayRecord? _holidayAt(DateTime date) {
    for (final item in _holidays) {
      if (_sameDate(item.date, date)) return item;
    }
    return null;
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
