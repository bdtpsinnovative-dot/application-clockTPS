import 'package:flutter/material.dart';

const workBlue = Color(0xFF2563EB);
const workSky = Color(0xFF0EA5E9);
const workBackground = Color(0xFFF8FAFC);
const workText = Color(0xFF1E293B);
const workMuted = Color(0xFF94A3B8);

class WorkHeader extends StatelessWidget {
  const WorkHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onMenu,
    this.action,
    this.child,
    this.bottomPadding = 56,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onMenu;
  final Widget? action;
  final Widget? child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 12,
        20,
        bottomPadding,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [workBlue, workSky],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (onMenu != null)
                IconButton.filledTonal(
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              if (onMenu != null) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                action!,
              ],
            ],
          ),
          if (child != null) ...[const SizedBox(height: 22), child!],
        ],
      ),
    );
  }
}

class WorkCard extends StatelessWidget {
  const WorkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class WorkCardTitle extends StatelessWidget {
  const WorkCardTitle({
    super.key,
    required this.icon,
    required this.title,
    this.color = workBlue,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: workText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'active' => ('ใช้งาน', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'approved' => (
        'อนุมัติแล้ว',
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      'on_time' => (
        'ตรงเวลา',
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
      ),
      'late' => ('มาสาย', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      'rejected' => (
        'ไม่อนุมัติ',
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
      ),
      'disabled' => ('ระงับ', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      _ => ('รออนุมัติ', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
