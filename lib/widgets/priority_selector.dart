import 'package:flutter/material.dart';

class PrioritySelector extends StatelessWidget {
  final String selectedPriority;
  final ValueChanged<String> onChanged;

  const PrioritySelector({
    super.key,
    required this.selectedPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Order requested by user (Urgent down to Low)
    final options = [
      {'value': 'urgent', 'label': 'ด่วนมาก', 'color': const Color(0xFFDC2626), 'bg': const Color(0xFFFEE2E2)},
      {'value': 'high', 'label': 'สูง', 'color': const Color(0xFFEA580C), 'bg': const Color(0xFFFFEDD5)},
      {'value': 'medium', 'label': 'ปานกลาง', 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7)},
      {'value': 'low', 'label': 'ต่ำ', 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selectedPriority == opt['value'];
        final color = opt['color'] as Color;
        final bg = opt['bg'] as Color;
        
        return InkWell(
          onTap: () => onChanged(opt['value'] as String),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? bg : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color.withOpacity(0.5) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              opt['label'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : const Color(0xFF64748B),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
