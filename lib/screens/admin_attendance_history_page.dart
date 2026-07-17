import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';

class AdminAttendanceHistoryPage extends StatefulWidget {
  const AdminAttendanceHistoryPage({
    super.key,
    required this.service,
  });

  final AuthFlowService service;

  @override
  State<AdminAttendanceHistoryPage> createState() => _AdminAttendanceHistoryPageState();
}

class _AdminAttendanceHistoryPageState extends State<AdminAttendanceHistoryPage> {
  String _activeTab = 'log'; // 'log' or 'summary'
  bool _loading = true;
  String? _error;

  // Filter states
  String _searchName = '';
  String _filterType = 'All';
  String _filterMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _filterDay = DateFormat('dd').format(DateTime.now());

  List<AdminHistoryRecord> _allRows = [];
  List<AppUser> _allUsers = [];
  List<HolidayRecord> _holidays = [];

  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parsedParts = _filterMonth.split('-');
      final year = int.parse(parsedParts[0]);
      
      final results = await Future.wait([
        widget.service.getAdminMonthlyHistory(_filterMonth),
        widget.service.getAdminUsers(),
        widget.service.getHolidays(year),
      ]);

      if (mounted) {
        setState(() {
          _allRows = results[0] as List<AdminHistoryRecord>;
          _allUsers = (results[1] as List<AppUser>).where((u) => u.status == 'active').toList();
          _holidays = results[2] as List<HolidayRecord>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // Days in selected month
  int get _daysInMonth {
    final parts = _filterMonth.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    return DateTime(y, m + 1, 0).day;
  }

  // Day list helper
  List<String> get _dayList {
    final list = <String>['All'];
    for (int i = 1; i <= _daysInMonth; i++) {
      list.add(i.toString().padLeft(2, '0'));
    }
    return list;
  }



  String _translateStatus(String status, DateTime date) {
    if (status.contains('approved') || status.contains('rejected') || status.contains('pending')) {
      // It is a request status
      String prefix = '';
      if (status.contains('sick_leave') || status.contains('ลาป่วย')) {
        prefix = 'ลาป่วย';
      } else if (status.contains('personal_leave') || status.contains('ลากิจ')) {
        prefix = 'ลากิจ';
      } else if (status.contains('annual_leave') || status.contains('ลาพักร้อน')) {
        prefix = 'ลาพักร้อน';
      } else if (status.contains('offsite') || status.contains('ออกหน้างาน')) {
        prefix = 'ออกหน้างาน';
      } else {
        prefix = 'ใบลา';
      }

      if (status.contains('approved')) {
        return '$prefix (อนุมัติ)';
      } else if (status.contains('rejected')) {
        return '$prefix (ปฏิเสธ)';
      } else {
        return '$prefix (รออนุมัติ)';
      }
    }

    switch (status) {
      case 'on_time':
        return 'ตรงเวลา';
      case 'late':
        return 'สาย';
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
      case 'offsite':
        return 'ออกหน้างาน';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'on_time' || s.contains('ตรงเวลา') || s.contains('approved') || s.contains('อนุมัติ')) {
      return const Color(0xFF10B981); // Green
    }
    if (s == 'late' || s.contains('สาย')) {
      return const Color(0xFFEA580C); // Orange/Red
    }
    if (s.contains('pending') || s.contains('รออนุมัติ')) {
      return const Color(0xFFF59E0B); // Amber
    }
    return const Color(0xFF64748B); // Slate
  }

  // Filtered Daily Log Rows
  List<AdminHistoryRecord> get _filteredRows {
    return _allRows.where((r) {
      // 1. Search Name
      if (_searchName.isNotEmpty && !r.userName.toLowerCase().contains(_searchName.toLowerCase())) {
        return false;
      }
      // 2. Filter Day
      if (_filterDay != 'All') {
        final dayPart = DateFormat('dd').format(r.date.toLocal());
        if (dayPart != _filterDay) return false;
      }
      // 3. Filter Type
      if (_filterType != 'All') {
        final thStatus = _translateStatus(r.status, r.date);
        if (!thStatus.contains(_filterType)) return false;
      }
      return true;
    }).toList();
  }

  // ──── Calculate Monthly stats ────
  Map<String, int> get _scheduledDaysAndYMDs {
    final parts = _filterMonth.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final totalDays = DateTime(y, m + 1, 0).day;
    int count = 0;
    final ymds = <String>[];

    final holidaySet = _holidays.map((h) => DateFormat('yyyy-MM-dd').format(h.date.toLocal())).toSet();

    for (int day = 1; day <= totalDays; day++) {
      final d = DateTime(y, m, day);
      final wd = d.weekday;
      final isWeekend = wd == DateTime.saturday || wd == DateTime.sunday;
      final ymdStr = DateFormat('yyyy-MM-dd').format(d);
      final isHoliday = holidaySet.contains(ymdStr);

      if (!isWeekend && !isHoliday) {
        count++;
        ymds.add(ymdStr);
      }
    }
    return {'scheduledDays': count};
  }

  List<Map<String, dynamic>> get _summaryData {
    final scheduledCount = _scheduledDaysAndYMDs['scheduledDays'] ?? 0;
    
    // Setup mappings
    final approvedLeaves = <String, double>{}; // user_ymd -> duration (1.0 or 0.5)
    final morningLeaves = <String, bool>{};    // user_ymd -> has morning leave
    final approvedOffsites = <String, bool>{}; // user_ymd -> is offsite

    for (var r in _allRows) {
      final ymd = DateFormat('yyyy-MM-dd').format(r.date.toLocal());
      final key = '${r.userName}_$ymd';

      if (r.type == 'leave' && r.status.contains('approved')) {
        final isHalf = r.status.contains('ครึ่ง') || r.status.contains('morning') || r.status.contains('afternoon');
        approvedLeaves[key] = isHalf ? 0.5 : 1.0;
        if (r.status.contains('ครึ่งเช้า') || r.status.contains('morning')) {
          morningLeaves[key] = true;
        }
      } else if (r.type == 'offsite' && r.status.contains('approved')) {
        approvedOffsites[key] = true;
      }
    }

    final summaryList = <Map<String, dynamic>>[];

    for (var u in _allUsers) {
      int presentCount = 0;
      int lateCount = 0;
      int lateMinutes = 0;
      double sickLeave = 0.0;
      double personalLeave = 0.0;
      double annualLeave = 0.0;
      int offsiteCount = 0;
      double totalWorkHours = 0.0;
      final coveredDays = <String>{};

      for (var r in _allRows) {
        if (r.userName != u.fullName) continue;

        final ymd = DateFormat('yyyy-MM-dd').format(r.date.toLocal());
        
        if (r.type == 'attendance') {
          if (r.status == 'on_time' || r.status == 'late') {
            final isWeekend = r.date.toLocal().weekday == DateTime.saturday || r.date.toLocal().weekday == DateTime.sunday;
            if (!isWeekend) {
              presentCount++;
              coveredDays.add(ymd);
            }
          }

          // Count manual leave registrations from attendance table
          final key = '${r.userName}_$ymd';
          if (!approvedLeaves.containsKey(key)) {
            if (r.status.contains('sick_leave')) {
              final val = r.status.contains('morning') || r.status.contains('afternoon') ? 0.5 : 1.0;
              sickLeave += val;
              if (val == 1.0) coveredDays.add(ymd);
            } else if (r.status.contains('personal_leave')) {
              final val = r.status.contains('morning') || r.status.contains('afternoon') ? 0.5 : 1.0;
              personalLeave += val;
              if (val == 1.0) coveredDays.add(ymd);
            } else if (r.status == 'annual_leave') {
              annualLeave += 1.0;
              coveredDays.add(ymd);
            }
          }

          if (r.status == 'offsite') {
            if (!approvedOffsites.containsKey(key)) {
              offsiteCount++;
            }
            coveredDays.add(ymd);
          }

          // Late calculation
          if (r.checkInAt != null) {
            final checkIn = r.checkInAt!.toLocal();
            final isMorningLeave = morningLeaves['${r.userName}_$ymd'] == true;
            final targetHour = isMorningLeave ? 13 : 9;
            final target = DateTime(checkIn.year, checkIn.month, checkIn.day, targetHour, 0);
            final diff = checkIn.difference(target).inMinutes;
            if (diff > 0) {
              lateCount++;
              lateMinutes += diff;
            }
          }

          // Compute work hours
          if (r.checkInAt != null && r.checkOutAt != null) {
            final checkIn = r.checkInAt!.toLocal();
            final checkOut = r.checkOutAt!.toLocal();
            final diffHours = checkOut.difference(checkIn).inMinutes / 60.0;
            if (diffHours > 0) {
              totalWorkHours += double.parse(diffHours.toStringAsFixed(1));
            }
          }
        } else if (r.type == 'leave' && r.status.contains('approved')) {
          final val = r.status.contains('ครึ่ง') || r.status.contains('morning') || r.status.contains('afternoon') ? 0.5 : 1.0;
          if (r.status.contains('ลาป่วย') || r.status.contains('sick_leave')) {
            sickLeave += val;
          } else if (r.status.contains('ลากิจ') || r.status.contains('personal_leave')) {
            personalLeave += val;
          } else if (r.status.contains('ลาพักร้อน') || r.status.contains('annual_leave')) {
            annualLeave += val;
          }
          if (val == 1.0) coveredDays.add(ymd);
        } else if (r.type == 'offsite' && r.status.contains('approved')) {
          offsiteCount++;
          coveredDays.add(ymd);
        }
      }

      // Calculate absent days
      int absentDays = 0;
      final holidaySet = _holidays.map((h) => DateFormat('yyyy-MM-dd').format(h.date.toLocal())).toSet();
      final parts = _filterMonth.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final totalDays = DateTime(y, m + 1, 0).day;

      for (int day = 1; day <= totalDays; day++) {
        final d = DateTime(y, m, day);
        final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
        final ymdStr = DateFormat('yyyy-MM-dd').format(d);
        final isHoliday = holidaySet.contains(ymdStr);

        if (!isWeekend && !isHoliday) {
          if (!coveredDays.contains(ymdStr)) {
            absentDays++;
          }
        }
      }

      final onTimeRate = presentCount > 0
          ? double.parse((((presentCount - lateCount) / presentCount) * 100).toStringAsFixed(1))
          : 0.0;

      summaryList.add({
        'user': u,
        'scheduledDays': scheduledCount,
        'presentCount': presentCount,
        'lateCount': lateCount,
        'lateMinutes': lateMinutes,
        'absentDays': absentDays,
        'sickLeave': sickLeave,
        'personalLeave': personalLeave,
        'annualLeave': annualLeave,
        'offsite': offsiteCount,
        'totalWorkHours': totalWorkHours,
        'onTimeRate': onTimeRate,
      });
    }

    if (_searchName.isNotEmpty) {
      return summaryList.where((s) {
        final user = s['user'] as AppUser;
        return user.fullName.toLowerCase().contains(_searchName.toLowerCase());
      }).toList();
    }

    return summaryList;
  }

  Future<void> _selectMonthPicker() async {
    final parts = _filterMonth.split('-');
    final currentYear = int.parse(parts[0]);
    final currentMonth = int.parse(parts[1]);

    int selectedYear = currentYear;
    int selectedMonth = currentMonth;

    final picked = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('เลือกเดือนรายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          setDialogState(() => selectedYear--);
                        },
                        icon: const Icon(Icons.keyboard_arrow_left_rounded, color: workBlue),
                      ),
                      Text(
                        'ปี พ.ศ. ${selectedYear + 543}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      IconButton(
                        onPressed: () {
                          setDialogState(() => selectedYear++);
                        },
                        icon: const Icon(Icons.keyboard_arrow_right_rounded, color: workBlue),
                      ),
                    ],
                  ),
                  const Divider(),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = selectedMonth == monthNum;
                      final monthName = DateFormat('MMM', 'th').format(DateTime(2026, monthNum));
                      return InkWell(
                        onTap: () {
                          setDialogState(() => selectedMonth = monthNum);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? workBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? workBlue : const Color(0xFFCBD5E1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            monthName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : workText,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก', style: TextStyle(color: workMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final monthStr = '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';
                    Navigator.pop(context, monthStr);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: workBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterMonth = picked;
        _filterDay = 'All'; // Reset day to prevent overflow
      });
      _loadData();
    }
  }

  Widget _buildMiniChip(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: workBlue.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: workBlue, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 11, color: workBlue),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final parts = _filterMonth.split('-');
            final displayMonthStr = DateFormat('MMMM yyyy', 'th').format(
              DateTime(int.parse(parts[0]), int.parse(parts[1])),
            );

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ตัวกรองข้อมูล',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: workText),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    // Month Picker
                    const Text('เลือกเดือนรายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workMuted)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        await _selectMonthPicker();
                        setSheetState(() {});
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayMonthStr,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: workBlue),
                            ),
                            const Icon(Icons.calendar_month_rounded, color: workBlue, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (_activeTab == 'log') ...[
                      const SizedBox(height: 16),
                      // Day Selector
                      const Text('เลือกวัน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workMuted)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterDay,
                            isExpanded: true,
                            items: _dayList.map((day) {
                              return DropdownMenuItem<String>(
                                value: day,
                                child: Text(day == 'All' ? 'ทุกวัน' : 'วันที่ $day'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _filterDay = val);
                                setSheetState(() {});
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Type Selector
                      const Text('สถานะการเช็คอิน/การลา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workMuted)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterType,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('ทุกสถานะ')),
                              DropdownMenuItem(value: 'ตรงเวลา', child: Text('ตรงเวลา')),
                              DropdownMenuItem(value: 'สาย', child: Text('สาย')),
                              DropdownMenuItem(value: 'ลาป่วย', child: Text('ลาป่วย')),
                              DropdownMenuItem(value: 'ลากิจ', child: Text('ลากิจ')),
                              DropdownMenuItem(value: 'ลาพักร้อน', child: Text('ลาพักร้อน')),
                              DropdownMenuItem(value: 'ออกหน้างาน', child: Text('ออกหน้างาน')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _filterType = val);
                                setSheetState(() {});
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _filterDay = 'All';
                                _filterType = 'All';
                                _filterMonth = DateFormat('yyyy-MM').format(DateTime.now());
                              });
                              _loadData();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('รีเซ็ตทั้งหมด', style: TextStyle(color: workMuted)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _loadData();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: workBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('นำไปใช้'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = _filterMonth.split('-');
    final selectedYear = int.parse(parts[0]);
    final selectedMonth = int.parse(parts[1]);
    final thaiYear = selectedYear + 543;
    final monthName = DateFormat('MMMM', 'th').format(DateTime(selectedYear, selectedMonth));

    String subtitleText = '';
    if (_activeTab == 'log') {
      if (_filterDay == 'All') {
        subtitleText = 'ประจำเดือน $monthName พ.ศ. $thaiYear';
      } else {
        subtitleText = 'ประจำวันที่ ${int.parse(_filterDay)} $monthName พ.ศ. $thaiYear';
      }
    } else {
      subtitleText = 'ประจำเดือน $monthName พ.ศ. $thaiYear';
    }

    final showTypeFilterChip = _activeTab == 'log' && _filterType != 'All';

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'รายงานการเข้างาน',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
            ),
            Text(
              subtitleText,
              style: const TextStyle(fontSize: 10.5, color: workMuted, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Unified Control Panel Container (Tabs + Search + Filters)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Sliding Segment Tabs
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 'log'),
                          child: Container(
                            margin: const EdgeInsets.all(2.0),
                            decoration: BoxDecoration(
                              color: _activeTab == 'log' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _activeTab == 'log'
                                  ? const [BoxShadow(color: Color(0x080F172A), blurRadius: 4, offset: Offset(0, 2))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.description_rounded,
                                  size: 16,
                                  color: _activeTab == 'log' ? workBlue : workMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'รายละเอียดรายวัน',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _activeTab == 'log' ? FontWeight.w700 : FontWeight.w500,
                                    color: _activeTab == 'log' ? workText : workMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activeTab = 'summary'),
                          child: Container(
                            margin: const EdgeInsets.all(2.0),
                            decoration: BoxDecoration(
                              color: _activeTab == 'summary' ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _activeTab == 'summary'
                                  ? const [BoxShadow(color: Color(0x080F172A), blurRadius: 4, offset: Offset(0, 2))]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assessment_rounded,
                                  size: 16,
                                  color: _activeTab == 'summary' ? workBlue : workMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'สรุปประจำเดือน',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: _activeTab == 'summary' ? FontWeight.w700 : FontWeight.w500,
                                    color: _activeTab == 'summary' ? workText : workMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Search & Filter Row
                Row(
                  children: [
                    // Clean Search Bar
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: workMuted, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'ค้นหาชื่อ...',
                                  hintStyle: TextStyle(color: workMuted, fontSize: 12.5),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(fontSize: 13),
                                onChanged: (val) {
                                  setState(() => _searchName = val.trim());
                                },
                              ),
                            ),
                            if (_searchName.isNotEmpty)
                              IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchName = '');
                                },
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.cancel_rounded, color: workMuted),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Compact Funnel Filter Button
                    InkWell(
                      onTap: _showFilterBottomSheet,
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: workMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Active filter indicator chips
          if (showTypeFilterChip)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMiniChip(_filterType, () {
                      setState(() => _filterType = 'All');
                      _loadData();
                    }),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Main content area
          Expanded(
            child: _loading
                ? const AppLoadingView(message: 'กำลังคำนวณและโหลดบันทึกประวัติ...')
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('โหลดข้อมูลล้มเหลว: $_error', style: const TextStyle(color: workText)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadData, child: const Text('ลองอีกครั้ง')),
                          ],
                        ),
                      )
                    : _activeTab == 'log'
                        ? _buildDailyLogView()
                        : _buildMonthlySummaryView(),
          ),
        ],
      ),
    );
  }

  // Widget 1: Daily Log list
  Widget _buildDailyLogView() {
    final rows = _filteredRows;
    if (rows.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลบันทึกเวลา', style: TextStyle(color: workMuted)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final checkInStr = row.checkInAt != null ? DateFormat('HH:mm').format(row.checkInAt!.toLocal()) : '--:--';
          final checkOutStr = row.checkOutAt != null ? DateFormat('HH:mm').format(row.checkOutAt!.toLocal()) : '--:--';
          
          final displayStatus = _translateStatus(row.status, row.date);
          final statusColor = _getStatusColor(row.status);

          // Calculate work hours
          double wh = 0.0;
          if (row.checkInAt != null && row.checkOutAt != null) {
            wh = row.checkOutAt!.toLocal().difference(row.checkInAt!.toLocal()).inMinutes / 60.0;
          }

          // Calculate late minutes
          int lateMin = 0;
          if (row.checkInAt != null && row.type == 'attendance') {
            final checkInLocal = row.checkInAt!.toLocal();
            // check morning leave
            final ymd = DateFormat('yyyy-MM-dd').format(row.date.toLocal());
            final isMorningLeave = _allRows.any((r) =>
                r.userName == row.userName &&
                DateFormat('yyyy-MM-dd').format(r.date.toLocal()) == ymd &&
                r.type == 'leave' &&
                r.status.contains('approved') &&
                (r.status.contains('ครึ่งเช้า') || r.status.contains('morning')));
            
            final targetHour = isMorningLeave ? 13 : 9;
            final target = DateTime(checkInLocal.year, checkInLocal.month, checkInLocal.day, targetHour, 0);
            final diff = checkInLocal.difference(target).inMinutes;
            if (diff > 0) lateMin = diff;
          }

          // Lookup matching active user to fetch their actual avatar URL
          AppUser? matchedUser;
          for (final u in _allUsers) {
            if (u.email.toLowerCase() == row.email.toLowerCase()) {
              matchedUser = u;
              break;
            }
          }

          final hasAvatar = matchedUser?.avatarUrl != null && matchedUser!.avatarUrl!.trim().isNotEmpty;
          final avatarUrl = hasAvatar
              ? (matchedUser.avatarUrl!.startsWith('r2://')
                  ? matchedUser.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                  : matchedUser.avatarUrl!)
              : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 1))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: statusColor, width: 4),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            image: hasAvatar
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: hasAvatar
                              ? null
                              : const Icon(
                                  Icons.person_rounded,
                                  color: workMuted,
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.userName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: workText),
                              ),
                              Text(
                                '${row.department.isEmpty ? '-' : row.department} · ${row.position.isEmpty ? '-' : row.position}',
                                style: const TextStyle(fontSize: 10.5, color: workMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Type & Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            displayStatus,
                            style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('วันที่บันทึก', style: TextStyle(fontSize: 10, color: workMuted)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM yyyy', 'th').format(row.date.toLocal()),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workText),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text('เข้า - ออก', style: TextStyle(fontSize: 10, color: workMuted)),
                            const SizedBox(height: 2),
                            Text(
                              row.type == 'attendance' ? '$checkInStr · $checkOutStr' : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: row.status == 'late' ? const Color(0xFFEA580C) : workText,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('ชม.ทำงาน / สาย', style: TextStyle(fontSize: 10, color: workMuted)),
                            const SizedBox(height: 2),
                            Text(
                              row.type == 'attendance'
                                  ? '${wh > 0 ? wh.toStringAsFixed(1) : '-'} ชม. / ${lateMin > 0 ? '$lateMin น.' : '-'}'
                                  : '-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: lateMin > 0 ? const Color(0xFFEA580C) : workText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (row.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'เหตุผล/หมายเหตุ: ${row.reason}',
                          style: const TextStyle(fontSize: 11, color: workMuted, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget 2: Monthly Summary list
  Widget _buildMonthlySummaryView() {
    final summaries = _summaryData;
    if (summaries.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลสรุปรายเดือน', style: TextStyle(color: workMuted)));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: summaries.length,
        itemBuilder: (context, index) {
          final s = summaries[index];
          final AppUser user = s['user'] as AppUser;
          final onTimeRate = s['onTimeRate'] as double;

          final hasAvatar = user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty;
          final avatarUrl = hasAvatar
              ? (user.avatarUrl!.startsWith('r2://')
                  ? user.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                  : user.avatarUrl!)
              : '';

          // Determine on-time rate color
          Color rateColor = const Color(0xFFEF4444); // Red (< 75%)
          if (onTimeRate >= 90) {
            rateColor = const Color(0xFF10B981); // Green (>= 90%)
          } else if (onTimeRate >= 75) {
            rateColor = const Color(0xFFF59E0B); // Amber (>= 75%)
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (User avatar + name + Circular progress)
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF1F5F9),
                        image: hasAvatar
                            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                            : null,
                      ),
                      child: hasAvatar ? null : const Icon(Icons.person_rounded, color: workMuted, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText),
                          ),
                          Text(
                            '${user.department.isEmpty ? '-' : user.department} · ${user.position.isEmpty ? '-' : user.position}',
                            style: const TextStyle(fontSize: 10.5, color: workMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Circular on-time progress indicator
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            value: onTimeRate / 100.0,
                            strokeWidth: 3.5,
                            backgroundColor: rateColor.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                          ),
                        ),
                        Text(
                          '${onTimeRate.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: rateColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // Stats row 1
                Row(
                  children: [
                    Expanded(child: _buildMetricCol(label: 'วันทำการ', value: '${s['scheduledDays']}', icon: Icons.calendar_month_rounded, color: workText)),
                    Expanded(child: _buildMetricCol(label: 'มาทำงาน', value: '${s['presentCount']}', icon: Icons.check_circle_rounded, color: const Color(0xFF10B981))),
                    Expanded(child: _buildMetricCol(label: 'มาสาย', value: '${s['lateCount']}', icon: Icons.watch_later_rounded, color: const Color(0xFFEA580C))),
                    Expanded(child: _buildMetricCol(label: 'สาย (นาที)', value: '${s['lateMinutes']}', icon: Icons.hourglass_bottom_rounded, color: const Color(0xFFEA580C))),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row 2
                Row(
                  children: [
                    Expanded(child: _buildMetricCol(label: 'ขาดงาน', value: '${s['absentDays']}', icon: Icons.cancel_rounded, color: const Color(0xFFEF4444))),
                    Expanded(child: _buildMetricCol(label: 'ลาป่วย', value: s['sickLeave'] > 0 ? '${s['sickLeave']}' : '0', icon: Icons.health_and_safety_rounded, color: const Color(0xFFEF4444))),
                    Expanded(child: _buildMetricCol(label: 'ลากิจ', value: s['personalLeave'] > 0 ? '${s['personalLeave']}' : '0', icon: Icons.work_off_rounded, color: const Color(0xFFF59E0B))),
                    Expanded(child: _buildMetricCol(label: 'ลาพักร้อน', value: s['annualLeave'] > 0 ? '${s['annualLeave']}' : '0', icon: Icons.beach_access_rounded, color: workBlue)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.75)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: workMuted, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
