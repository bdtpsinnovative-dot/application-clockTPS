import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/widgets/work_ui.dart';

void main() {
  group('StatusBadge Widget Tests', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders active status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'active')));
      expect(find.text('ใช้งาน'), findsOneWidget);
    });

    testWidgets('renders approved status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'approved')));
      expect(find.text('อนุมัติแล้ว'), findsOneWidget);
    });

    testWidgets('renders on_time status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'on_time')));
      expect(find.text('ตรงเวลา'), findsOneWidget);
    });

    testWidgets('renders late status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'late')));
      expect(find.text('มาสาย'), findsOneWidget);
    });

    testWidgets('renders rejected status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'rejected')));
      expect(find.text('ไม่อนุมัติ'), findsOneWidget);
    });

    testWidgets('renders disabled status correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'disabled')));
      expect(find.text('ระงับ'), findsOneWidget);
    });

    testWidgets('renders pending or unknown status as waiting for approval', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'pending')));
      expect(find.text('รออนุมัติ'), findsOneWidget);

      await tester.pumpWidget(buildTestableWidget(const StatusBadge(status: 'xyz')));
      expect(find.text('รออนุมัติ'), findsOneWidget);
    });
  });

  group('WorkCardTitle Widget Tests', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders icon and title text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const WorkCardTitle(
            icon: Icons.access_time_filled,
            title: 'เวลาเข้า-ออกงานล่าสุด',
          ),
        ),
      );

      expect(find.byIcon(Icons.access_time_filled), findsOneWidget);
      expect(find.text('เวลาเข้า-ออกงานล่าสุด'), findsOneWidget);
    });
  });

  group('WorkCard Widget Tests', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders its child inside the card', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const WorkCard(
            child: Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });
  });

  group('WorkHeader Widget Tests', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders title and optional subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const WorkHeader(
            title: 'ลงเวลาเข้างาน',
            subtitle: 'กรุณาสแกนใบหน้าของคุณ',
          ),
        ),
      );

      expect(find.text('ลงเวลาเข้างาน'), findsOneWidget);
      expect(find.text('กรุณาสแกนใบหน้าของคุณ'), findsOneWidget);
    });

    testWidgets('renders menu button when onMenu is provided and handles tap', (WidgetTester tester) async {
      var menuTapped = false;
      await tester.pumpWidget(
        buildTestableWidget(
          WorkHeader(
            title: 'แดชบอร์ด',
            onMenu: () {
              menuTapped = true;
            },
          ),
        ),
      );

      final menuButtonFinder = find.byIcon(Icons.menu_rounded);
      expect(menuButtonFinder, findsOneWidget);

      await tester.tap(menuButtonFinder);
      await tester.pump();

      expect(menuTapped, isTrue);
    });

    testWidgets('renders optional action widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const WorkHeader(
            title: 'คำขอเลิกงาน',
            action: Icon(Icons.settings),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
