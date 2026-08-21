import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/work_models.dart';

/// Animated Floating Action Button in the Bottom Navigation Bar
/// neatly integrated within the circular FAB bounds (No Overflow):
/// 1. Not Checked In (ยังไม่เข้างาน): Pulsing breathing glow + Clock Icon + 'ลงเวลา'
/// 2. Checked In & Working (เข้างานแล้ว): Smooth rotating ring + Realtime live timer 'HH:mm'
/// 3. Checked Out (ออกงานแล้ว): Green checkmark + Summary of total working hours 'X ชม.'
class AttendanceNavFab extends StatefulWidget {
  const AttendanceNavFab({
    super.key,
    required this.attendance,
    required this.isSelected,
    required this.onTap,
  });

  final AttendanceRecord? attendance;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<AttendanceNavFab> createState() => _AttendanceNavFabState();
}

class _AttendanceNavFabState extends State<AttendanceNavFab>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  Timer? _liveTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _updateLiveTimer();
  }

  @override
  void didUpdateWidget(covariant AttendanceNavFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attendance?.checkInAt != widget.attendance?.checkInAt ||
        oldWidget.attendance?.checkOutAt != widget.attendance?.checkOutAt) {
      _updateLiveTimer();
    }
  }

  void _updateLiveTimer() {
    final att = widget.attendance;
    final isWorking = att?.checkInAt != null && att?.checkOutAt == null;
    if (isWorking) {
      _liveTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _currentTime = DateTime.now();
          });
        }
      });
    } else {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attendance;
    final isCompleted = att?.checkInAt != null && att?.checkOutAt != null;
    final isWorking = att?.checkInAt != null && !isCompleted;
    final isNotCheckedIn = !isWorking && !isCompleted;

    const double baseSize = 56.0;
    final double size = widget.isSelected ? 60.0 : baseSize;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Ambient Glow Ring around the FAB (within bounds)
          if (isNotCheckedIn)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.22);
                final opacity = (1.0 - _pulseController.value) * 0.4;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB).withValues(alpha: opacity),
                    ),
                  ),
                );
              },
            )
          else if (isWorking)
            RotationTransition(
              turns: _rotationController,
              child: CustomPaint(
                size: Size(size + 6, size + 6),
                painter: const _DashedGlowRingPainter(
                  color: Color(0xFF34D399),
                ),
              ),
            ),

          // 2. Main Circular FAB Button with Content Inside (Zero overflow)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCompleted
                    ? const [Color(0xFF16A34A), Color(0xFF15803D)]
                    : isWorking
                        ? const [Color(0xFF059669), Color(0xFF047857)]
                        : const [Color(0xFF2E7CFF), Color(0xFF1450E0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isCompleted
                          ? const Color(0xFF16A34A)
                          : isWorking
                              ? const Color(0xFF059669)
                              : const Color(0xFF2E7CFF))
                      .withValues(alpha: widget.isSelected ? 0.48 : 0.32),
                  blurRadius: widget.isSelected ? 14 : 9,
                  spreadRadius: widget.isSelected ? 1 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: _buildInnerContent(
                  isNotCheckedIn: isNotCheckedIn,
                  isWorking: isWorking,
                  isCompleted: isCompleted,
                  att: att,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerContent({
    required bool isNotCheckedIn,
    required bool isWorking,
    required bool isCompleted,
    required AttendanceRecord? att,
  }) {
    if (isWorking && att?.checkInAt != null) {
      final diff = _currentTime.difference(att!.checkInAt!);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');

      return Column(
        key: const ValueKey('working_content'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Blinking live dot
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.35 + (_pulseController.value * 0.65),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF86EFAC),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.timelapse_rounded,
                color: Colors.white,
                size: 13,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$h:$m:$s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    if (isCompleted && att?.checkInAt != null && att?.checkOutAt != null) {
      final diff = att!.checkOutAt!.difference(att.checkInAt!);
      final totalH = diff.inHours;
      final totalM = diff.inMinutes % 60;
      final summaryText = totalH > 0
          ? '$totalH.${(totalM / 6).floor()} ชม.'
          : '$totalM นาที';

      return Column(
        key: const ValueKey('completed_content'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(height: 2),
          Text(
            summaryText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      );
    }

    // Default: Not checked in yet
    return const Column(
      key: ValueKey('checkin_content'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.access_time_filled_rounded,
          color: Colors.white,
          size: 22,
        ),
        SizedBox(height: 2),
        Text(
          'ลงเวลา',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _DashedGlowRingPainter extends CustomPainter {
  const _DashedGlowRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const count = 12;
    const sweep = (2 * math.pi) / count;
    const arcLen = sweep * 0.55;

    for (var i = 0; i < count; i++) {
      final startAngle = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcLen,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGlowRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
