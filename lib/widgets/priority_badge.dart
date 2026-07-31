import 'package:flutter/material.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;
  final bool isCompact;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color color;
    Color border;
    IconData icon;
    String label;

    switch (priority.toLowerCase()) {
      case 'urgent':
        bg = const Color(0xFFFEE2E2);
        color = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        icon = Icons.local_fire_department_rounded;
        label = 'ด่วนมาก';
        break;
      case 'high':
        bg = const Color(0xFFFFEDD5);
        color = const Color(0xFFEA580C);
        border = const Color(0xFFFED7AA);
        icon = Icons.keyboard_double_arrow_up_rounded;
        label = 'สูง';
        break;
      case 'low':
        bg = const Color(0xFFE0F2FE);
        color = const Color(0xFF0284C7);
        border = const Color(0xFFBAE6FD);
        icon = Icons.keyboard_double_arrow_down_rounded;
        label = 'ต่ำ';
        break;
      case 'medium':
      default:
        bg = const Color(0xFFFEF3C7);
        color = const Color(0xFFD97706);
        border = const Color(0xFFFDE68A);
        icon = Icons.drag_handle_rounded;
        label = 'ปานกลาง';
        break;
    }

    final double fontSize = isCompact ? 10.0 : 11.5;
    final double iconSize = isCompact ? 12.0 : 14.0;
    final EdgeInsets padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
