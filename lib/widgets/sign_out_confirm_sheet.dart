import 'package:flutter/material.dart';
import 'work_ui.dart';

/// Opens a beautifully styled NexHR confirmation sheet for signing out.
Future<bool?> showSignOutConfirmSheet(
  BuildContext context, {
  required Future<void> Function() onConfirm,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SignOutConfirmSheetContent(onConfirm: onConfirm),
  );
}

class _SignOutConfirmSheetContent extends StatefulWidget {
  const _SignOutConfirmSheetContent({required this.onConfirm});

  final Future<void> Function() onConfirm;

  @override
  State<_SignOutConfirmSheetContent> createState() =>
      _SignOutConfirmSheetContentState();
}

class _SignOutConfirmSheetContentState
    extends State<_SignOutConfirmSheetContent> {
  bool _isSigningOut = false;

  Future<void> _handleConfirm() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop(true);
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        } catch (_) {}
      }
      await widget.onConfirm();
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

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
                const SizedBox(height: 24),

                // Red logout icon badge with soft glow
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFEE2E2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                const Text(
                  'ยืนยันการออกจากระบบ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: workText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'คุณต้องการออกจากระบบหรือไม่?\nข้อมูลการทำงานของคุณจะได้รับการบันทึกไว้อย่างปลอดภัย',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: workMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),

                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSigningOut
                            ? null
                            : () => Navigator.of(context).pop(false),
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

                    // Confirm sign out button
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSigningOut ? null : _handleConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSigningOut
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'ออกจากระบบ',
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
