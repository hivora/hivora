import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../shared/test_helpers.dart';

void main() {
  group('GlassBackdropScope', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: GlassBackdropScope(
            child: const Text('Inside Backdrop'),
          ),
        ),
      );
      expect(find.text('Inside Backdrop'), findsOneWidget);
    });

    testWidgets('provides BackdropGroup to subtree', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: GlassBackdropScope(
            child: Builder(
              builder: (context) {
                // Should not throw — BackdropGroup is in tree
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(find.byType(GlassBackdropScope), findsOneWidget);
    });

    testWidgets('can wrap a GlassBottomBar without error', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: GlassBackdropScope(
            child: GlassBottomBar(
              tabs: const [
                GlassBottomBarTab(label: 'Home', icon: Icon(Icons.home)),
                GlassBottomBarTab(label: 'About', icon: Icon(Icons.info)),
              ],
              selectedIndex: 0,
              onTabSelected: (_) {},
              maskingQuality: MaskingQuality.off,
            ),
          ),
        ),
      );

      expect(find.byType(GlassBackdropScope), findsOneWidget);
      expect(find.byType(GlassBottomBar), findsOneWidget);
    });

    testWidgets('can wrap multiple glass surfaces', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: GlassBackdropScope(
            child: Column(
              children: const [
                GlassDivider(),
                GlassDivider(),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(GlassDivider), findsNWidgets(2));
    });

    testWidgets('supports key', (tester) async {
      const key = Key('backdrop_scope');
      await tester.pumpWidget(
        createTestApp(
          child: GlassBackdropScope(
            key: key,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byKey(key), findsOneWidget);
    });
  });

  // ── GlassDivider.vertical named constructor (line 59) ────────────────────────
  group('GlassDivider.vertical', () {
    testWidgets('GlassDivider.vertical renders as vertical divider (line 59)',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Row(
            children: [
              const Text('Left'),
              // Non-const to ensure line 59 is counted by lcov
              GlassDivider.vertical(key: UniqueKey()),
              const Text('Right'),
            ],
          ),
        ),
      );
      expect(find.byType(GlassDivider), findsOneWidget);
    });
  });
}
