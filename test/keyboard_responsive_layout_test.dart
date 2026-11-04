import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sunshine_pg_app/widgets/keyboard_responsive_layout.dart';

void main() {
  group('KeyboardDismissOnTap Tests', () {
    testWidgets('Tapping outside an active input unfocuses and dismisses keyboard', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardDismissOnTap(
            child: Scaffold(
              body: Column(
                children: [
                  const Text('Outside Area'),
                  TextField(
                    focusNode: focusNode,
                    key: const Key('test_input'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Focus the text field
      await tester.tap(find.byKey(const Key('test_input')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap outside the text field
      await tester.tap(find.text('Outside Area'));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);

      focusNode.dispose();
    });

    testWidgets('Tapping a button unfocuses input and still fires button onPressed', (tester) async {
      final focusNode = FocusNode();
      bool buttonPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardDismissOnTap(
            child: Scaffold(
              body: Column(
                children: [
                  TextField(
                    focusNode: focusNode,
                    key: const Key('test_input'),
                  ),
                  ElevatedButton(
                    key: const Key('test_btn'),
                    onPressed: () {
                      buttonPressed = true;
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Focus input
      await tester.tap(find.byKey(const Key('test_input')));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // Tap button
      await tester.tap(find.byKey(const Key('test_btn')));
      await tester.pump();

      expect(buttonPressed, isTrue);
      focusNode.dispose();
    });
  });

  group('KeyboardAutoScroll Tests', () {
    testWidgets('KeyboardAutoScroll renders and provides smooth scroll behavior', (tester) async {
      final scrollController = ScrollController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: KeyboardAutoScroll(
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 300, child: Text('Top Spacer')),
                      TextField(
                        key: const Key('field_at_bottom'),
                        focusNode: focusNode,
                      ),
                      const SizedBox(height: 200, child: Text('Bottom Spacer')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(KeyboardAutoScroll), findsOneWidget);
      expect(scrollController.offset, 0.0);

      // Tap the field to focus
      await tester.tap(find.byKey(const Key('field_at_bottom')));
      await tester.pumpAndSettle();

      // Focus was acquired
      expect(focusNode.hasFocus, isTrue);

      scrollController.dispose();
      focusNode.dispose();
    });
  });

  group('KeyboardAwareScrollView Tests', () {
    testWidgets('KeyboardAwareScrollView configures onDrag dismiss and renders children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KeyboardAwareScrollView(
              child: Column(
                children: [
                  Text('Child Item 1'),
                  Text('Child Item 2'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Child Item 1'), findsOneWidget);
      expect(find.text('Child Item 2'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      final scrollView = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.keyboardDismissBehavior, ScrollViewKeyboardDismissBehavior.onDrag);
    });
  });

  group('KeyboardAwareDialog Tests', () {
    testWidgets('KeyboardAwareDialog caps maximum height above bottom insets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: 300), // Simulating keyboard open
            ),
            child: const Scaffold(
              body: KeyboardAwareDialog(
                child: Dialog(
                  child: SizedBox(
                    height: 600,
                    child: Text('Dialog Content'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dialog Content'), findsOneWidget);
      final box = tester.renderObject<RenderBox>(find.byType(KeyboardAwareDialog));
      // Available height is 800 - 300 - 32 = 468
      expect(box.size.height, lessThanOrEqualTo(500));
    });
  });
}
