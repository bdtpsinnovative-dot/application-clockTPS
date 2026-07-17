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
    required this.isActive,
  });

  final AuthFlowService service;
  final VoidCallback onMenu;
  final VoidCallback onOpenRequests;
  final bool isActive;

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

  @override
  void didUpdateWidget(covariant WorkCalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadMonthBackground();
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _month = DateTime(DateTime.now().year, DateTime.now().month);
      _selected = DateTime.now();
    });
    return _loadMonth();
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

  Future<void> _loadMonthBackground() async {
    try {
      final results = await Future.wait([
        widget.service.getAttendanceHistory(_month.year, _month.month),
        widget.service.getHolidays(_month.year),
      ]);
      if (mounted) {
        setState(() {
          _attendance = results[0] as List<AttendanceRecord>;
          _holidays = results[1] as List<HolidayRecord>;
          _error = null;
        });
      }
    } catch (_) {
      // Ignore background load errors silently
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
        onRefresh: _handleRefresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            WorkHeader(
              title: 'ปฏิทินตารางงาน',
              subtitle: 'การลงเวลาและวันหยุด',
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: selectedHoliday != null
                                      ? const Color(0xFFFEE2E2)
                                      : selectedAttendance != null
                                          ? _getStatusColor(selectedAttendance.status).withValues(alpha: 0.1)
                                          : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  selectedHoliday != null
                                      ? Icons.celebration_rounded
                                      : selectedAttendance != null
                                          ? (selectedAttendance.status == 'offsite'
                                              ? Icons.location_on_rounded
                                              : selectedAttendance.status == 'late'
                                                  ? Icons.history_toggle_off_rounded
                                                  : Icons.badge_rounded)
                                          : Icons.event_busy_rounded,
                                  color: selectedHoliday != null
                                      ? const Color(0xFFEF4444)
                                      : selectedAttendance != null
                                          ? _getStatusColor(selectedAttendance.status)
                                          : workMuted,
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
                                              ? _getStatusLabel(selectedAttendance.status)
                                              : 'ไม่มีบันทึกเวลาทำงาน'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: workText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
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
                            ],
                          ),
                          if (selectedAttendance != null && selectedHoliday == null) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.login_rounded, size: 14, color: Color(0xFF22C55E)),
                                          SizedBox(width: 6),
                                          Text(
                                            'เวลาเข้างาน',
                                            style: TextStyle(
                                              color: workMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(selectedAttendance.checkInAt),
                                        style: const TextStyle(
                                          color: workText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 32,
                                  color: const Color(0xFFF1F5F9),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.logout_rounded, size: 14, color: Color(0xFFEF4444)),
                                          SizedBox(width: 6),
                                          Text(
                                            'เวลาออกงาน',
                                            style: TextStyle(
                                              color: workMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(selectedAttendance.checkOutAt),
                                        style: const TextStyle(
                                          color: workText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'on_time':
        return 'เข้างานตรงเวลา';
      case 'late':
        return 'เข้างานสาย';
      case 'offsite':
        return 'ปฏิบัติงานนอกสถานที่';
      case 'sick_leave_full':
        return 'ลาป่วย (เต็มวัน)';
      case 'sick_leave_morning':
        return 'ลาป่วย (ครึ่งเช้า)';
      case 'sick_leave_afternoon':
        return 'ลาป่วย (ครึ่งบ่าย)';
      case 'personal_leave_full':
        return 'ลากิจ (เต็มวัน)';
      case 'personal_leave_morning':
        return 'ลากิจ (ครึ่งเช้า)';
      case 'personal_leave_afternoon':
        return 'ลากิจ (ครึ่งบ่าย)';
      case 'annual_leave':
        return 'ลาพักร้อน';
      case 'no_record':
      case 'absent':
        return 'ไม่มีบันทึกการเข้างาน';
      default:
        return 'บันทึกสถานะ: $status';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'on_time':
        return const Color(0xFF22C55E);
      case 'late':
        return const Color(0xFFF59E0B);
      case 'offsite':
        return const Color(0xFF3B82F6);
      case 'sick_leave_full':
      case 'sick_leave_morning':
      case 'sick_leave_afternoon':
      case 'personal_leave_full':
      case 'personal_leave_morning':
      case 'personal_leave_afternoon':
      case 'annual_leave':
        return const Color(0xFF8B5CF6);
      case 'no_record':
      case 'absent':
        return const Color(0xFFEF4444);
      default:
        return workMuted;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return DateFormat('HH:mm').format(dateTime) + ' น.';
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
