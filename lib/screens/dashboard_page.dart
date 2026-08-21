import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'face_scanner_page.dart';
import 'selfie_camera_page.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../widgets/skeleton_loading.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.service,
    required this.onMenu,
    required this.onSignOut,
    required this.isActive,
    this.onAttendanceChanged,
  });

  final AppUser user;
  final AuthFlowService service;
  final VoidCallback onMenu;
  final Future<void> Function() onSignOut;
  final bool isActive;
  final void Function(AttendanceRecord? attendance)? onAttendanceChanged;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  AttendanceRecord? _attendance;
  List<HolidayRecord> _upcomingHolidays = const [];
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  List<Map<String, dynamic>> _workLocations = [];
  List<WorkRequestRecord> _myRequests = [];
  Position? _currentPosition;
  double? _distanceToClosest;
  String? _closestLocationName;
  double? _closestRadius;
  bool _isInsideAny = false;
  bool _isOffsiteToday = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadToday();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadTodayBackground();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _calculateDistanceAndCheckArea() {
    if (_currentPosition == null || _workLocations.isEmpty) return;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _isOffsiteToday = _myRequests.any(
      (r) =>
          r.isOffsite &&
          r.status == 'approved' &&
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day,
    );

    _isInsideAny = false;
    double minDistance = double.infinity;
    String closestName = '';
    double closestRadius = 100.0;

    for (final loc in _workLocations) {
      double lat = 0.0;
      double lng = 0.0;
      double radius = 100.0;

      if (loc['latitude'] is num) {
        lat = (loc['latitude'] as num).toDouble();
      } else if (loc['latitude'] is String) {
        lat = double.tryParse(loc['latitude'] as String) ?? 0.0;
      }

      if (loc['longitude'] is num) {
        lng = (loc['longitude'] as num).toDouble();
      } else if (loc['longitude'] is String) {
        lng = double.tryParse(loc['longitude'] as String) ?? 0.0;
      }

      if (loc['radius_m'] is num) {
        radius = (loc['radius_m'] as num).toDouble();
      } else if (loc['radius_m'] is String) {
        radius = double.tryParse(loc['radius_m'] as String) ?? 100.0;
      }

      final String name = loc['name'] as String? ?? 'สาขา';

      final double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat,
        lng,
      );

      if (distance <= radius) {
        _isInsideAny = true;
        _closestLocationName = name;
        _distanceToClosest = distance;
        _closestRadius = radius;
        break;
      }

      if (distance < minDistance) {
        minDistance = distance;
        closestName = name;
        closestRadius = radius;
      }
    }

    if (!_isInsideAny) {
      _closestLocationName = closestName;
      _distanceToClosest = minDistance;
      _closestRadius = closestRadius;
    }
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
        widget.service.getWorkLocations(),
        widget.service.getMyRequests(),
      ]);
      final attendance = results[0] as AttendanceRecord?;
      final holidays = results[1] as List<HolidayRecord>;
      final locations = results[2] as List<Map<String, dynamic>>;
      final requests = results[3] as List<WorkRequestRecord>;

      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      final upcoming = holidays.where((h) {
        final hDate = DateTime(h.date.year, h.date.month, h.date.day);
        return !hDate.isBefore(today);
      }).toList();

      upcoming.sort((a, b) => a.date.compareTo(b.date));

      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        try {
          currentPos = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _attendance = attendance;
          _upcomingHolidays = upcoming;
          _workLocations = locations;
          _myRequests = requests;
          _currentPosition = currentPos;
          _calculateDistanceAndCheckArea();
        });
        widget.onAttendanceChanged?.call(attendance);
      }
    } catch (error) {
      if (error is AccountSuspendedException ||
          error.toString().contains('ระงับ') ||
          error.toString().toLowerCase().contains('suspended') ||
          error.toString().contains('อนุมัติ') ||
          error.toString().contains('403')) {
        try {
          final user = await widget.service.getMe();
          if (user.status == 'suspended' || user.status == 'disabled') {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text(
                    'บัญชีถูกระงับ',
                    textAlign: TextAlign.center,
                  ),
                  content: const Text(
                    'บัญชีของคุณถูกระงับการใช้งาน\nกรุณาติดต่อผู้ดูแลระบบ',
                    textAlign: TextAlign.center,
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSignOut();
                      },
                      child: const Text('ตกลง'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        } catch (_) {}
      }
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTodayBackground() async {
    try {
      final results = await Future.wait([
        widget.service.getAttendance(DateTime.now()),
        widget.service.getHolidays(DateTime.now().year),
        widget.service.getWorkLocations(),
        widget.service.getMyRequests(),
      ]);
      final attendance = results[0] as AttendanceRecord?;
      final holidays = results[1] as List<HolidayRecord>;
      final locations = results[2] as List<Map<String, dynamic>>;
      final requests = results[3] as List<WorkRequestRecord>;

      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      final upcoming = holidays.where((h) {
        final hDate = DateTime(h.date.year, h.date.month, h.date.day);
        return !hDate.isBefore(today);
      }).toList();

      upcoming.sort((a, b) => a.date.compareTo(b.date));

      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        try {
          currentPos = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _attendance = attendance;
          _upcomingHolidays = upcoming;
          _workLocations = locations;
          _myRequests = requests;
          _currentPosition = currentPos;
          _calculateDistanceAndCheckArea();
          _error = null;
        });
        widget.onAttendanceChanged?.call(attendance);
      }
    } catch (error) {
      if (error is AccountSuspendedException ||
          error.toString().contains('ระงับ') ||
          error.toString().toLowerCase().contains('suspended') ||
          error.toString().contains('อนุมัติ') ||
          error.toString().contains('403')) {
        try {
          final user = await widget.service.getMe();
          if (user.status == 'suspended' || user.status == 'disabled') {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text(
                    'บัญชีถูกระงับ',
                    textAlign: TextAlign.center,
                  ),
                  content: const Text(
                    'บัญชีของคุณถูกระงับการใช้งาน\nกรุณาติดต่อผู้ดูแลระบบ',
                    textAlign: TextAlign.center,
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSignOut();
                      },
                      child: const Text('ตกลง'),
                    ),
                  ],
                ),
              );
            }
          }
        } catch (_) {}
      }
      // Ignore other background load errors silently
    }
  }

  Future<String> _getDeviceId() async {
    // ignore: invalid_use_of_visible_for_testing_member
    if (AuthFlowService.mockDeviceId != null) {
      // ignore: invalid_use_of_visible_for_testing_member
      return AuthFlowService.mockDeviceId!;
    }
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      return webInfo.userAgent ?? 'web_browser_device';
    }
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

  Future<Position> _determinePosition({bool requireAccurate = false}) async {
    if (!kIsWeb) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('กรุณาอนุญาตการเข้าถึงตำแหน่งที่ตั้ง');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'คุณได้ปฏิเสธการเข้าถึงตำแหน่งอย่างถาวร กรุณาเปิดสิทธิ์ในตั้งค่าอุปกรณ์',
        );
      }
    }

    Position? position;
    for (var attempt = 0; attempt < (requireAccurate && !kIsWeb ? 3 : 1); attempt++) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {}
      if (!requireAccurate || kIsWeb || (position != null && position.accuracy <= 100)) break;
    }

    if (position == null || (!kIsWeb && requireAccurate && position.accuracy > 100)) {
      throw Exception('GPS ยังไม่แม่นยำ กรุณาออกไปยังบริเวณเปิดและลองอีกครั้ง');
    }

    if (!kIsWeb && position.isMocked) {
      throw Exception(
        'ระบบตรวจพบการจำลองพิกัด (Mock Location) ไม่สามารถลงเวลาได้',
      );
    }

    return position;
  }

  String _areaNameFor(Position? position) {
    if (position == null) return 'ไม่สามารถระบุตำแหน่ง';
    Map<String, dynamic>? closest;
    var closestDistance = double.infinity;
    for (final location in _workLocations) {
      final lat =
          (location['latitude'] as num?)?.toDouble() ??
          double.tryParse('${location['latitude']}');
      final lng =
          (location['longitude'] as num?)?.toDouble() ??
          double.tryParse('${location['longitude']}');
      if (lat == null || lng == null) continue;
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = location;
      }
    }
    if (closest == null) return 'นอกพื้นที่';
    final radius =
        (closest['radius_m'] as num?)?.toDouble() ??
        double.tryParse('${closest['radius_m']}') ??
        100;
    if (closestDistance <= radius) {
      return closest['name'] as String? ?? 'พื้นที่ทำงาน';
    }
    return _attendance?.isOffsite == true || _attendance?.status == 'offsite'
        ? 'ออกหน้างาน'
        : 'นอกพื้นที่';
  }

  Future<String> _resolveAreaName(Position? position) async {
    final base = _areaNameFor(position);
    if (position == null ||
        (!base.startsWith('นอกพื้นที่') && !base.startsWith('ออกหน้างาน'))) {
      return base;
    }
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'format': 'json',
          'accept-language': 'th',
        },
        options: Options(headers: {'User-Agent': 'HRManagementApp/1.0'}),
      );
      final addr = res.data?['address'] as Map<String, dynamic>?;
      if (addr != null) {
        final road = addr['road'] as String?;
        final sub =
            addr['quarter'] as String? ??
            addr['suburb'] as String? ??
            addr['neighbourhood'] as String?;
        final dist =
            addr['city_district'] as String? ?? addr['district'] as String?;
        final prov = addr['province'] as String? ?? addr['city'] as String?;
        final parts = [
          if (road != null && road.isNotEmpty) road,
          if (sub != null && sub.isNotEmpty) sub,
          if (dist != null && dist.isNotEmpty) dist,
          if (prov != null &&
              prov.isNotEmpty &&
              (dist == null || !prov.contains(dist)))
            prov,
        ];
        if (parts.isNotEmpty) {
          return '$base (${parts.join(', ')})';
        }
      }
    } catch (_) {}
    return base;
  }

  Future<bool> _confirmClockOut(String areaName) async {
    if (!mounted) return false;
    final now = DateTime.now();
    final checkInAt = _attendance?.checkInAt;
    String? workDurationText;
    if (checkInAt != null) {
      final diff = now.difference(checkInAt);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (hours > 0) {
        workDurationText = '$hours ชม. $minutes นาที';
      } else {
        workDurationText = '$minutes นาที';
      }
    }

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => _ClockOutConfirmSheet(
            now: now,
            areaName: areaName,
            checkInAt: checkInAt,
            workDurationText: workDurationText,
          ),
        ) ??
        false;
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
      setState(() => _submitting = true);
      final mode = await widget.service.getCheckInMode();

      final position = await _determinePosition(requireAccurate: !kIsWeb);
      final deviceId = await _getDeviceId();

      File? imageFile;
      List<double> faceVector = const [];

      if (!kIsWeb) {
        if (mode == 'selfie') {
          // โหมดเซลฟี่: เปิดหน้ากล้องที่สร้างเองเพื่อถ่ายรูป (ไม่ใช้ ImagePicker)
          setState(() => _submitting = false);
          if (!mounted) return;
          final photoFile = await Navigator.of(context).push<File>(
            MaterialPageRoute(builder: (_) => const SelfieCameraPage()),
          );
          if (!mounted) return;
          setState(() => _submitting = true);
          if (photoFile == null) {
            setState(() => _submitting = false);
            return;
          }
          imageFile = photoFile;
        } else {
          // โหมดสแกนใบหน้า: สแกนด้วย FaceScannerPage
          if (!mounted) return;
          setState(() => _submitting = false);
          final result = await Navigator.of(context).push<FaceScannerResult>(
            MaterialPageRoute(builder: (_) => const FaceScannerPage()),
          );
          if (result == null) return;
          setState(() => _submitting = true);
          imageFile = result.imageFile;
          faceVector = result.faceVector;
        }
      }

      String? photoUrl;
      if (imageFile != null) {
        photoUrl = await widget.service.uploadImage(imageFile);
      }

      await widget.service.checkIn(
        lat: position.latitude,
        lng: position.longitude,
        deviceId: deviceId,
        faceVector: faceVector,
        photoUrl: photoUrl,
        accuracyM: position.accuracy,
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
      Position? position;
      try {
        position = await _determinePosition();
      } catch (_) {
        // Checkout must remain available even when GPS is unavailable.
      }

      final areaName = await _resolveAreaName(position);
      final confirmed = await _confirmClockOut(areaName);
      if (!confirmed) return;

      setState(() => _submitting = true);

      await widget.service.checkOut(
        lat: position?.latitude,
        lng: position?.longitude,
        accuracyM: position?.accuracy,
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
    final isCompleted = checkedIn && checkedOut;

    Widget buttonIcon;
    if (isCompleted) {
      buttonIcon = const Icon(
        Icons.check_circle_rounded,
        size: 20,
        color: Color(0xFF22C55E),
      );
    } else if (checkedIn) {
      buttonIcon = const Icon(Icons.logout_rounded, size: 20);
    } else {
      buttonIcon = const FaceScanIcon(color: workBlue, size: 20);
    }

    String buttonText;
    if (isCompleted) {
      buttonText = 'ลงเวลาวันนี้เรียบร้อย';
    } else if (checkedIn) {
      buttonText = 'ลงเวลาออกงาน';
    } else {
      buttonText = 'ลงเวลาเข้างาน';
    }

    Color foregroundColor;
    if (isCompleted) {
      foregroundColor = workMuted;
    } else if (checkedIn) {
      foregroundColor = const Color(0xFFEF4444);
    } else {
      foregroundColor = workBlue;
    }

    final hasData = _attendance != null;

    return ColoredBox(
      color: workBackground,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _loading && !hasData
            ? const DashboardSkeleton(key: ValueKey('dashboard_skeleton'))
            : Stack(
                key: const ValueKey('dashboard_content'),
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
                                'เวลาทำงาน ${attendance?.workStartTime ?? widget.user.workStartTime} - ${attendance?.workEndTime ?? widget.user.workEndTime}',
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
                              onPressed: (_submitting || isCompleted)
                                  ? null
                                  : _handleClockInOut,
                              icon: buttonIcon,
                              label: Text(buttonText),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(210, 56),
                                maximumSize: const Size(260, 56),
                                backgroundColor: isCompleted
                                    ? const Color(0xFFF1F5F9)
                                    : Colors.white,
                                foregroundColor: foregroundColor,
                                disabledBackgroundColor: const Color(
                                  0xFFF1F5F9,
                                ),
                                disabledForegroundColor: workMuted,
                                elevation: isCompleted ? 0 : 8,
                                shadowColor: workBlue.withValues(alpha: 0.22),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(
                            children: [
                              if (_loading)
                                const LinearProgressIndicator(minHeight: 3),
                              if (_error != null) ...[
                                _ErrorStrip(
                                  message: _error!,
                                  onRetry: _loadToday,
                                ),
                                const SizedBox(height: 14),
                              ],
                              _buildGeofenceStatusWidget(),
                              const SizedBox(height: 14),
                              WorkCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.login_rounded,
                                                    size: 14,
                                                    color: Color(0xFF22C55E),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'เวลาเข้างาน',
                                                    style: TextStyle(
                                                      color: workMuted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (attendance?.checkInAt !=
                                                      null) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            attendance!
                                                                    .status ==
                                                                'late'
                                                            ? const Color(
                                                                0xFFF59E0B,
                                                              )
                                                            : const Color(
                                                                0xFF22C55E,
                                                              ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _timeText(
                                                  attendance?.checkInAt,
                                                ),
                                                style: TextStyle(
                                                  color:
                                                      attendance?.checkInAt ==
                                                          null
                                                      ? workMuted
                                                      : workText,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (attendance?.checkInAt != null &&
                                                  attendance?.locationName.isNotEmpty == true) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_outlined,
                                                      size: 12,
                                                      color: workMuted,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                      child: Text(
                                                        attendance!.locationName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: workMuted,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 28,
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.logout_rounded,
                                                    size: 14,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'เวลาออกงาน',
                                                    style: TextStyle(
                                                      color: workMuted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _timeText(
                                                  attendance?.checkOutAt,
                                                ),
                                                style: TextStyle(
                                                  color:
                                                      attendance?.checkOutAt ==
                                                          null
                                                      ? workMuted
                                                      : workText,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (attendance?.checkOutAt != null &&
                                                  attendance?.checkOutLocationName.isNotEmpty == true) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_outlined,
                                                      size: 12,
                                                      color: workMuted,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Flexible(
                                                      child: Text(
                                                        attendance!.checkOutLocationName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: workMuted,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
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
                                    if (attendance != null &&
                                        (attendance.locationName.isNotEmpty ||
                                            attendance
                                                .checkOutLocationName
                                                .isNotEmpty)) ...[
                                      const Divider(
                                        height: 20,
                                        color: Color(0xFFF1F5F9),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: workMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              attendance.checkOutAt != null
                                                  ? 'เข้า: ${attendance.locationName.isEmpty ? '-' : attendance.locationName} · ออก: ${attendance.checkOutLocationName.isEmpty ? '-' : attendance.checkOutLocationName}'
                                                  : 'เข้า: ${attendance.locationName.isEmpty ? '-' : attendance.locationName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: workMuted,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              WorkCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const WorkCardTitle(
                                      icon: Icons.event_available_rounded,
                                      title:
                                          'วันหยุดที่กำลังจะถึงที่เหลือในปีนี้',
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(height: 14),
                                    if (_upcomingHolidays.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'ไม่มีวันหยุดที่กำลังจะถึงในช่วงนี้',
                                            style: TextStyle(
                                              color: workMuted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _upcomingHolidays.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final h = _upcomingHolidays[index];
                                          final isCurrentMonth =
                                              h.date.month ==
                                              DateTime.now().month;

                                          if (isCurrentMonth) {
                                            return Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFCA5A5,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFEF4444,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          DateFormat(
                                                            'd',
                                                          ).format(h.date),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                height: 1.1,
                                                              ),
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                            'MMM',
                                                          ).format(h.date),
                                                          style: TextStyle(
                                                            color: Colors.white
                                                                .withValues(
                                                                  alpha: 0.9,
                                                                ),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                h.name,
                                                                style: const TextStyle(
                                                                  color:
                                                                      workText,
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xFFEF4444,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                              child: const Text(
                                                                'เดือนนี้',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 9,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                            'EEEE',
                                                          ).format(h.date),
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    workMuted,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            return Opacity(
                                              opacity: 0.55,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF1F5F9,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        '${h.date.day}/${h.date.month}',
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF475569,
                                                          ),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            h.name,
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      workText,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            DateFormat(
                                                              'EEEE, d MMM',
                                                            ).format(h.date),
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      workMuted,
                                                                  fontSize: 9,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
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
                    const AppLoadingOverlay(message: 'กำลังบันทึกเวลา...'),
                ],
              ),
      ),
    );
  }

  String _timeText(DateTime? value) {
    return value == null
        ? 'ยังไม่มีข้อมูล'
        : DateFormat('HH:mm น.').format(value);
  }

  Widget _buildGeofenceStatusWidget() {
    if (_loading && _currentPosition == null) {
      return const SizedBox.shrink();
    }

    String message = '';
    Color textColor = workMuted;
    IconData icon = Icons.gps_off_rounded;

    if (_isOffsiteToday) {
      message = 'ปฏิบัติงานนอกสถานที่ (ออกหน้างาน)';
      textColor = workBlue;
      icon = Icons.directions_car_outlined;
    } else if (_isInsideAny) {
      message =
          'พื้นที่: $_closestLocationName (รัศมีไม่เกิน ${_closestRadius?.toStringAsFixed(0)} เมตร)';
      textColor = const Color(0xFF22C55E);
      icon = Icons.location_on_rounded;
    } else if (_currentPosition != null &&
        _closestLocationName != null &&
        _distanceToClosest != null) {
      message =
          'นอกพื้นที่: ห่างจาก $_closestLocationName ${_distanceToClosest!.toStringAsFixed(0)} เมตร (กำหนดไว้ไม่เกิน ${_closestRadius?.toStringAsFixed(0)} เมตร)';
      textColor = const Color(0xFFEF4444);
      icon = Icons.gpp_maybe_rounded;
    } else {
      message = 'กำลังดึงตำแหน่งพิกัด GPS...';
      textColor = workMuted;
      icon = Icons.gps_not_fixed_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

class FaceScanIcon extends StatelessWidget {
  const FaceScanIcon({super.key, required this.color, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FaceScanPainter(color: color),
    );
  }
}

class _FaceScanPainter extends CustomPainter {
  _FaceScanPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 1. Draw 4 corner brackets (viewfinder)
    final bracketLen = w * 0.22;

    // Top-Left
    canvas.drawLine(Offset(0, 0), Offset(bracketLen, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, bracketLen), paint);

    // Top-Right
    canvas.drawLine(Offset(w, 0), Offset(w - bracketLen, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, bracketLen), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, h), Offset(bracketLen, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - bracketLen), paint);

    // Bottom-Right
    canvas.drawLine(Offset(w, h), Offset(w - bracketLen, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - bracketLen), paint);

    // 2. Draw face outline in center
    final facePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(w * 0.5, h * 0.45);
    final radius = w * 0.24;
    canvas.drawCircle(center, radius, facePaint);

    final shouldersPath = Path();
    shouldersPath.moveTo(w * 0.22, h * 0.88);
    shouldersPath.quadraticBezierTo(w * 0.5, h * 0.65, w * 0.78, h * 0.88);
    canvas.drawPath(shouldersPath, facePaint);

    // 3. Draw horizontal scanning line
    final scanPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(w * 0.12, h * 0.52),
      Offset(w * 0.88, h * 0.52),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceScanPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ClockOutConfirmSheet extends StatelessWidget {
  const _ClockOutConfirmSheet({
    required this.now,
    required this.areaName,
    this.checkInAt,
    this.workDurationText,
  });

  final DateTime now;
  final String areaName;
  final DateTime? checkInAt;
  final String? workDurationText;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomSafe),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Orange Clock-Out Icon Badge with Soft Glow
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFEDD5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEA580C),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'ยืนยันลงเวลาออกงาน',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: workText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                const Text(
                  'คุณต้องการบันทึกเวลาออกงานสำหรับวันนี้ใช่หรือไม่?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: workMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Clock Out Time Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.access_time_filled_rounded,
                              color: Color(0xFFEA580C),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'เวลาออกงาน',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: workMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${DateFormat('HH:mm').format(now)} น.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // Location Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: workBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'สถานที่',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: workMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              areaName,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: workText,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (checkInAt != null && workDurationText != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        // Work Duration Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.timelapse_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'ชั่วโมงทำงาน',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: workMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              workDurationText!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: workText,
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Confirm Button
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'ยืนยันออกงาน',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

