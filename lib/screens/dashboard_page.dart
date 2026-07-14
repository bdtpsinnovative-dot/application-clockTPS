import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'face_scanner_page.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.service,
    required this.onMenu,
  });

  final AppUser user;
  final AuthFlowService service;
  final VoidCallback onMenu;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  AttendanceRecord? _attendance;
  HolidayRecord? _nextHoliday;
  List<LeaveBalanceRecord>? _leaveBalances;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadToday();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.getAttendance(DateTime.now()),
        widget.service.getHolidays(DateTime.now().year),
        widget.service.getLeaveBalances(DateTime.now().year),
      ]);
      final attendance = results[0] as AttendanceRecord?;
      final holidays = results[1] as List<HolidayRecord>;
      final leaveBalances = results[2] as List<LeaveBalanceRecord>;

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      HolidayRecord? nextHoliday;
      for (final h in holidays) {
        final hDate = DateTime(h.date.year, h.date.month, h.date.day);
        if (!hDate.isBefore(today)) {
          if (nextHoliday == null || hDate.isBefore(nextHoliday.date)) {
            nextHoliday = h;
          }
        }
      }

      if (mounted) {
        setState(() {
          _attendance = attendance;
          _nextHoliday = nextHoliday;
          _leaveBalances = leaveBalances;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _getDeviceId() async {
    if (AuthFlowService.mockDeviceId != null) {
      return AuthFlowService.mockDeviceId!;
    }
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios_unknown_device';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isMacOS) {
      final macosInfo = await deviceInfo.macOsInfo;
      return macosInfo.systemGUID ?? 'macos_unknown_device';
    }
    return 'unknown_device';
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('กรุณาอนุญาตการเข้าถึงตำแหน่งที่ตั้ง');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('คุณได้ปฏิเสธการเข้าถึงตำแหน่งอย่างถาวร กรุณาเปิดสิทธิ์ในตั้งค่าอุปกรณ์');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    if (position.isMocked) {
      throw Exception('ระบบตรวจพบการจำลองพิกัด (Mock Location) ไม่สามารถลงเวลาได้');
    }

    return position;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleClockInOut() async {
    final attendance = _attendance;
    final checkedIn = attendance?.checkInAt != null;
    final checkedOut = attendance?.checkOutAt != null;

    if (checkedIn && !checkedOut) {
      await _clockOut();
    } else {
      await _clockIn();
    }
  }

  Future<void> _clockIn() async {
    try {
      final position = await _determinePosition();
      final deviceId = await _getDeviceId();

      if (!mounted) return;
      final result = await Navigator.of(context).push<FaceScannerResult>(
        MaterialPageRoute(builder: (_) => const FaceScannerPage()),
      );

      if (result == null) return;

      setState(() => _submitting = true);

      final photoUrl = await widget.service.uploadImage(result.imageFile);

      await widget.service.checkIn(
        lat: position.latitude,
        lng: position.longitude,
        deviceId: deviceId,
        faceVector: result.faceVector,
        photoUrl: photoUrl,
      );

      await _loadToday();
      _showMessage('เช็คอินเข้างานสำเร็จ');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _clockOut() async {
    try {
      final position = await _determinePosition();

      setState(() => _submitting = true);

      await widget.service.checkOut(
        lat: position.latitude,
        lng: position.longitude,
      );

      await _loadToday();
      _showMessage('เช็คเอาท์ออกงานสำเร็จ');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = _attendance;
    final checkedIn = attendance?.checkInAt != null;
    final checkedOut = attendance?.checkOutAt != null;

    return ColoredBox(
      color: workBackground,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadToday,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            WorkHeader(
              title: widget.user.fullName,
              subtitle: widget.user.position.isNotEmpty
                  ? widget.user.position
                  : 'พนักงาน',
              onMenu: widget.onMenu,
              bottomPadding: 72,
              child: Column(
                children: [
                  Text(
                    DateFormat('HH:mm:ss').format(_now),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    DateFormat('EEEE d MMM yyyy').format(_now),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เวลาทำงาน 09:00 - 18:00',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Center(
                child: FilledButton.icon(
                  key: const ValueKey('clock_in_out_button'),
                  onPressed: _submitting ? null : _handleClockInOut,
                  icon: Icon(
                    checkedIn && !checkedOut
                        ? Icons.logout_rounded
                        : Icons.fingerprint_rounded,
                  ),
                  label: Text(
                    checkedIn && !checkedOut ? 'ลงเวลาออกงาน' : 'ลงเวลาเข้างาน',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(210, 56),
                    maximumSize: const Size(250, 56),
                    backgroundColor: Colors.white,
                    foregroundColor: checkedIn && !checkedOut
                        ? const Color(0xFFEF4444)
                        : workBlue,
                    elevation: 8,
                    shadowColor: workBlue.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  if (_loading) const LinearProgressIndicator(minHeight: 3),
                  if (_error != null) ...[
                    _ErrorStrip(message: _error!, onRetry: _loadToday),
                    const SizedBox(height: 14),
                  ],
                  WorkCard(
                    child: Column(
                      children: [
                        const WorkCardTitle(
                          icon: Icons.today_rounded,
                          title: 'สถานะการลงเวลาวันนี้',
                        ),
                        const SizedBox(height: 12),
                        _TimeRow(
                          icon: Icons.login_rounded,
                          title: 'บันทึกเวลาเข้างาน',
                          time: _timeText(attendance?.checkInAt),
                          status: attendance?.checkInAt == null
                              ? 'pending'
                              : attendance!.status,
                        ),
                        const Divider(height: 1),
                        _TimeRow(
                          icon: Icons.logout_rounded,
                          title: 'บันทึกเวลาออกงาน',
                          time: _timeText(attendance?.checkOutAt),
                          status: attendance?.checkOutAt == null
                              ? 'pending'
                              : 'approved',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  WorkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WorkCardTitle(
                          icon: Icons.event_available_rounded,
                          title: 'วันหยุดที่กำลังจะถึง',
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        if (_nextHoliday == null)
                          const Text(
                            'ไม่มีวันหยุดที่กำลังจะถึงในช่วงนี้',
                            style: TextStyle(color: workMuted),
                          )
                        else
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('d').format(_nextHoliday!.date),
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM').format(_nextHoliday!.date),
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nextHoliday!.name,
                                      style: const TextStyle(
                                        color: workText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEEE').format(_nextHoliday!.date),
                                      style: const TextStyle(color: workMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  WorkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WorkCardTitle(
                          icon: Icons.assessment_outlined,
                          title: 'สิทธิวันลาคงเหลือประจำปี',
                          color: workSky,
                        ),
                        const SizedBox(height: 16),
                        if (_leaveBalances == null)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_leaveBalances!.isEmpty)
                          const Text(
                            'ไม่พบข้อมูลสิทธิวันลาประจำปี',
                            style: TextStyle(color: workMuted),
                          )
                        else
                          ..._leaveBalances!.map((b) {
                            Color color = workBlue;
                            if (b.leaveType.contains('ป่วย')) {
                              color = const Color(0xFF22C55E);
                            } else if (b.leaveType.contains('กิจ')) {
                              color = const Color(0xFFF59E0B);
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 13),
                              child: _QuotaBar(
                                label: b.leaveType,
                                value: b.remaining.toInt(),
                                total: b.quota.toInt(),
                                color: color,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (_submitting)
        const AppLoadingOverlay(
          message: 'กำลังบันทึกเวลา...',
        ),
    ],
  ),
);
  }

  String _timeText(DateTime? value) {
    return value == null
        ? 'ยังไม่มีข้อมูล'
        : DateFormat('HH:mm น.').format(value);
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.title,
    required this.time,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String time;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: workMuted, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: workText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(color: workMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          StatusBadge(status: status),
        ],
      ),
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$value / $total วัน'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 8,
            color: color,
            backgroundColor: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
            ),
          ),
          IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}
