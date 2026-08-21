import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/attendance_nav_fab.dart';

void main() {
  testWidgets('AttendanceNavFab renders state 1 (Not Checked In) correctly', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AttendanceNavFab(
              attendance: null,
              isSelected: false,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('checkin_content')), findsOneWidget);
    expect(find.text('ลงเวลา'), findsOneWidget);
    expect(find.byIcon(Icons.access_time_filled_rounded), findsOneWidget);

    await tester.tap(find.byType(AttendanceNavFab));
    expect(tapped, isTrue);
  });

  testWidgets('AttendanceNavFab renders state 2 (Working Live Timer) correctly', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final checkInAt = now.subtract(const Duration(hours: 3, minutes: 25, seconds: 10));

    final attendance = AttendanceRecord(
      date: now,
      status: 'on_time',
      userId: 'user-1',
      checkInAt: checkInAt,
      checkOutAt: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AttendanceNavFab(
              attendance: attendance,
              isSelected: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('working_content')), findsOneWidget);
    expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);
    expect(find.textContaining(':'), findsWidgets);
  });

  testWidgets('AttendanceNavFab renders state 3 (Completed Summary) correctly', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final checkInAt = DateTime(now.year, now.month, now.day, 9, 0);
    final checkOutAt = DateTime(now.year, now.month, now.day, 18, 15);

    final attendance = AttendanceRecord(
      date: now,
      status: 'on_time',
      userId: 'user-1',
      checkInAt: checkInAt,
      checkOutAt: checkOutAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AttendanceNavFab(
              attendance: attendance,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('completed_content')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('9.2 ชม.'), findsOneWidget);
  });
}
