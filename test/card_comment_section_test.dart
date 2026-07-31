import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/widgets/card_comment_section.dart';

void main() {
  test('comment media URLs resolve Cloudflare R2 and API paths', () {
    expect(
      resolveCommentMediaUrl('r2://comments/photo.webp', 'https://api.test'),
      'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/comments/photo.webp',
    );
    expect(
      resolveCommentMediaUrl('/uploads/photo.webp', 'https://api.test'),
      'https://api.test/uploads/photo.webp',
    );
    expect(
      resolveCommentMediaUrl('https://cdn.test/photo.webp', 'https://api.test'),
      'https://cdn.test/photo.webp',
    );
  });

  test('comment avatars resolve Cloudflare URLs before rendering', () {
    expect(
      resolveCommentAvatarUrl(
        'r2://avatars/user.webp',
        'https://api.test',
      ),
      'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/avatars/user.webp',
    );
    expect(
      resolveCommentAvatarUrl('/avatars/user.webp', 'https://api.test'),
      'https://api.test/avatars/user.webp',
    );
  });

  testWidgets('docked comment composer uses compact actions', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.test');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CardCommentSection(
              service: AuthFlowService(),
              cardId: 'card-1',
              taskId: 'task-1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(quill.QuillEditor), findsOneWidget);
    expect(find.byTooltip('แนบรูปภาพ'), findsOneWidget);
    expect(find.byTooltip('ตัวหนา'), findsOneWidget);
    expect(find.byTooltip('ตัวเอียง'), findsOneWidget);
    expect(find.byTooltip('รายการหัวข้อ'), findsOneWidget);
    expect(find.byTooltip('กล่าวถึงสมาชิก'), findsOneWidget);
    expect(find.byType(quill.QuillSimpleToolbar), findsNothing);

    await tester.tap(find.byTooltip('ตัวหนา'));
    await tester.pump();
    expect(find.byType(quill.QuillSimpleToolbar), findsNothing);

    final clearance = find.byKey(
      const ValueKey('comment-composer-scroll-clearance'),
    );
    expect(clearance, findsOneWidget);
    expect(
      tester.getTopLeft(clearance).dy,
      greaterThan(
        tester
            .getBottomLeft(find.text('ยังไม่มีการพูดคุย เริ่มคอมเมนต์เพื่ออัปเดตทีมได้เลย'))
            .dy,
      ),
      reason: 'Composer clearance must follow the final comment content.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('focused comment editor stays above the iOS keyboard', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.test');
    final parentScrollController = ScrollController();
    addTearDown(parentScrollController.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            resizeToAvoidBottomInset: false,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  key: const ValueKey('card-detail-scroll'),
                  controller: parentScrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 580),
                      CardCommentSection(
                        service: AuthFlowService(),
                        cardId: 'card-1',
                        taskId: 'task-1',
                        parentScrollController: parentScrollController,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byType(quill.QuillEditor));
    await tester.pumpAndSettle();
    final editorFocusNode = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .focusNode;
    editorFocusNode.requestFocus();
    await tester.pump();
    expect(editorFocusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(
      editorFocusNode.hasFocus,
      isFalse,
      reason: 'Tapping blank space must dismiss the comment keyboard.',
    );

    editorFocusNode.requestFocus();
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('card-detail-scroll')),
      const Offset(0, -80),
    );
    await tester.pump();
    expect(
      editorFocusNode.hasFocus,
      isTrue,
      reason: 'Scrolling must keep the comment keyboard open.',
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    tester.binding.handleMetricsChanged();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 250));

    final visibleBottom = tester.view.physicalSize.height - 320;
    expect(
      tester.getBottomRight(find.byType(quill.QuillEditor)).dy,
      lessThanOrEqualTo(visibleBottom - 12),
      reason: 'The focused composer must scroll above the keyboard.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('nested sheets stay above the card comment composer', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.test');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var nestedSheetReceivedTap = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (context) => GestureDetector(
                      key: const ValueKey('nested-sheet-content'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => nestedSheetReceivedTap = true,
                      child: const SizedBox(height: 320, width: double.infinity),
                    ),
                  ),
                  child: const Text('เปิดรายการย่อย'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: CardCommentSection(
                      service: AuthFlowService(),
                      cardId: 'card-1',
                      taskId: 'task-1',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('เปิดรายการย่อย'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 810));
    await tester.pump();

    expect(nestedSheetReceivedTap, isTrue);
  });
}
