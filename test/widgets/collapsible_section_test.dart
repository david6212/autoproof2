import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/widgets/common/collapsible_section.dart';

/// Folding is how the car page ranks seventeen panels without losing any of
/// them. That only works if two promises hold: a folded section still says
/// what is inside it, and it stays the way the reader left it.
///
/// Break either one and folding stops being hierarchy and becomes hiding.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  Widget section({
    bool initiallyExpanded = false,
    String? persistKey,
    String? summary = '12 שדות',
  }) =>
      CollapsibleSection(
        title: 'מפרט טכני מלא',
        summary: summary,
        initiallyExpanded: initiallyExpanded,
        persistKey: persistKey,
        child: const Text('דגם מנוע B48B20A'),
      );

  group('collapsed', () {
    testWidgets('shows the summary, not just the title', (tester) async {
      // A bare title makes the reader open the section to find out whether
      // they wanted it — which costs more than leaving it open would have.
      await tester.pumpWidget(host(section()));

      expect(find.text('מפרט טכני מלא'), findsOneWidget);
      expect(find.text('12 שדות'), findsOneWidget);
      expect(find.text('דגם מנוע B48B20A'), findsNothing);
    });

    testWidgets('opens on tap and hides the summary once open', (tester) async {
      await tester.pumpWidget(host(section()));

      await tester.tap(find.text('מפרט טכני מלא'));
      await tester.pumpAndSettle();

      expect(find.text('דגם מנוע B48B20A'), findsOneWidget);
      // Redundant beside the content it was standing in for.
      expect(find.text('12 שדות'), findsNothing);
    });

    testWidgets('a section with no summary still renders', (tester) async {
      await tester.pumpWidget(host(section(summary: null)));

      expect(tester.takeException(), isNull);
      expect(find.text('מפרט טכני מלא'), findsOneWidget);
    });
  });

  group('the animation', () {
    testWidgets('finishes within 200ms', (tester) async {
      // The spec's number, and the reason for it: longer than this and the
      // panel reads as resisting the tap rather than answering it.
      await tester.pumpWidget(host(section()));

      await tester.tap(find.text('מפרט טכני מלא'));
      await tester.pump();

      final finder = find.byType(CollapsibleSection);
      await tester.pump(const Duration(milliseconds: 100));
      final midway = tester.getSize(finder).height;

      await tester.pump(const Duration(milliseconds: 100));
      final atLimit = tester.getSize(finder).height;

      await tester.pump(const Duration(milliseconds: 300));
      final wellAfter = tester.getSize(finder).height;

      expect(midway, lessThan(atLimit),
          reason: 'it should still have been opening at 100ms');
      expect(atLimit, wellAfter,
          reason: 'still growing after 200ms — the duration grew');
    });
  });

  group('the reader is remembered', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('a tap is written under the namespaced key', (tester) async {
      await tester.pumpWidget(host(section(persistKey: 'spec')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('מפרט טכני מלא'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(CollapsibleSection.prefsKey('spec')), isTrue);
      // Namespaced so 'spec' cannot collide with an unrelated preference.
      expect(prefs.getBool('spec'), isNull);
    });

    testWidgets('a stored choice beats the default', (tester) async {
      SharedPreferences.setMockInitialValues({
        // The mock store prefixes every key. Seeding without it writes a
        // value the plugin will never read back.
        'flutter.${CollapsibleSection.prefsKey('spec')}': true,
      });

      await tester.pumpWidget(host(section(persistKey: 'spec')));
      await tester.pumpAndSettle();

      expect(find.text('דגם מנוע B48B20A'), findsOneWidget,
          reason: 'opened three times before means open by default now');
    });

    testWidgets('restoring does not animate', (tester) async {
      // Otherwise every screen would open with a panel unfolding by itself,
      // which reads as the app doing something rather than as the state the
      // reader left behind.
      SharedPreferences.setMockInitialValues({
        // The mock store prefixes every key. Seeding without it writes a
        // value the plugin will never read back.
        'flutter.${CollapsibleSection.prefsKey('spec')}': true,
      });

      await tester.pumpWidget(host(section(persistKey: 'spec')));
      await tester.pump(); // lets the async read land
      await tester.pump(); // the frame that applies it

      expect(find.text('דגם מנוע B48B20A'), findsOneWidget,
          reason: 'the restored state should be there immediately');
    });

    testWidgets('without a persistKey nothing is written', (tester) async {
      await tester.pumpWidget(host(section()));
      await tester.tap(find.text('מפרט טכני מלא'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('reachable without sight or a mouse', () {
    testWidgets('announces itself as a button and reports its state',
        (tester) async {
      await tester.pumpWidget(host(section()));

      final handle = tester.ensureSemantics();

      // One node, not three: the summary belongs to the button that opens it.
      expect(
        tester.getSemantics(find.bySemanticsLabel('מפרט טכני מלא, 12 שדות')),
        containsSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
