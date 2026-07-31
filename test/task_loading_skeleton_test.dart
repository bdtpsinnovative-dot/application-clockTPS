import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';

void main() {
  testWidgets('assignment loading mirrors filters and task cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AssignmentListSkeleton()),
      ),
    );

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(SkeletonCircle), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('board loading shows columns and card placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: TaskBoardSkeleton(viewportFraction: 0.90),
          ),
        ),
      ),
    );

    expect(find.byType(SkeletonLine), findsWidgets);
    expect(find.byType(SkeletonCircle), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
