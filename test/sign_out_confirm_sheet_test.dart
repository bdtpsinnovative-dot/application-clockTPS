import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/widgets/sign_out_confirm_sheet.dart';

void main() {
  testWidgets('showSignOutConfirmSheet renders correctly and cancels', (
    WidgetTester tester,
  ) async {
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSignOutConfirmSheet(
                context,
                onConfirm: () async {
                  confirmed = true;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันการออกจากระบบ'), findsOneWidget);
    expect(find.text('คุณต้องการออกจากระบบหรือไม่?\nข้อมูลการทำงานของคุณจะได้รับการบันทึกไว้อย่างปลอดภัย'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsOneWidget);

    // Tap cancel
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันการออกจากระบบ'), findsNothing);
    expect(confirmed, isFalse);
  });

  testWidgets('showSignOutConfirmSheet confirms and triggers onConfirm', (
    WidgetTester tester,
  ) async {
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSignOutConfirmSheet(
                context,
                onConfirm: () async {
                  confirmed = true;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap confirm sign out
    await tester.tap(find.widgetWithText(FilledButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('ยืนยันการออกจากระบบ'), findsNothing);
  });
}
