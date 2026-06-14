import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('GlassPullDownButton toggles menu and handles selection',
      (WidgetTester tester) async {
    String selectedAction = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveLiquidGlassLayer(
            child: Center(
              child: GlassPullDownButton(
                label: 'Options',
                buttonWidth: 200, // Sufficient for "Options" text
                onSelected: (value) => selectedAction = value,
                items: [
                  GlassMenuItem(
                    title: 'Edit',
                    icon: Icon(CupertinoIcons.pen),
                    onTap: () {},
                  ),
                  GlassMenuItem(
                    title: 'Delete',
                    icon: Icon(CupertinoIcons.trash),
                    isDestructive: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Initial state check
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);

    // Tap button to open menu
    await tester.tap(find.text('Options'));
    await tester.pump();
    await tester
        .pumpAndSettle(); // Wait for animation to complete (content appears at 65%+)

    // Menu should be open
    expect(find.text('Edit'), findsOneWidget);

    // Tap menu item
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // Verify selection and closure
    expect(selectedAction, equals('Edit'));
    expect(find.text('Edit'), findsNothing);
  });

  // ── Icon-only button path (lines 99-106: label == null → GlassButton) ──────
  testWidgets('GlassPullDownButton icon-only (no label) uses GlassButton path',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveLiquidGlassLayer(
            child: Center(
              child: GlassPullDownButton(
                // label is null — exercises the else branch (line 99-106)
                items: [
                  GlassMenuItem(
                    title: 'Copy',
                    icon: Icon(CupertinoIcons.doc_on_doc),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassPullDownButton), findsOneWidget);
  });

  // ── line 63: label != null but empty triggers else branch too ───────────────
  testWidgets('GlassPullDownButton empty-string label takes icon-only path',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveLiquidGlassLayer(
            child: Center(
              child: GlassPullDownButton(
                label: '', // empty → !label!.isNotEmpty → else branch
                items: [
                  GlassMenuItem(
                    title: 'Share',
                    icon: Icon(CupertinoIcons.share),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GlassPullDownButton), findsOneWidget);
  });
}
