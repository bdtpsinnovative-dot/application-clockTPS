import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_management/screens/task_board_page.dart';

void main() {
  test('compact board exposes more neighboring columns', () {
    final regular = boardViewportFraction(false);
    final compact = boardViewportFraction(true);

    expect(regular, 0.90);
    expect(compact, 0.72);
    expect(compact, lessThan(regular));
  });

  testWidgets('board background tap dismisses search focus but drag keeps it', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardKeyboardDismissRegion(
            child: ListView(
              children: [
                TextField(focusNode: focusNode),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();
    expect(
      focusNode.hasFocus,
      isTrue,
      reason: 'Scrolling the board must not dismiss the search keyboard.',
    );

    await tester.tapAt(const Offset(300, 500));
    await tester.pump();
    expect(
      focusNode.hasFocus,
      isFalse,
      reason: 'Tapping blank board space must dismiss the search keyboard.',
    );
  });

  testWidgets('board page indicator shows the current column', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BoardPageIndicator(currentPage: 1, pageCount: 3),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('board-page-indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('board-page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-page-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-page-dot-2')), findsOneWidget);

    expect(
      tester.getSize(find.byKey(const ValueKey('board-page-dot-1'))).width,
      greaterThan(
        tester.getSize(find.byKey(const ValueKey('board-page-dot-0'))).width,
      ),
    );
  });
}
