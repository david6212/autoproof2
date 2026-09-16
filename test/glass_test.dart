import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/presentation/widgets/app_nav_bar.dart';
import 'package:bonnetcheck/presentation/widgets/glass.dart';
import 'package:bonnetcheck/presentation/widgets/photo_viewer.dart';

/// The glass pass: frosted surfaces where something is behind them.
///
/// What can go wrong with glass is not how it looks but what it does to the
/// text on it. A see-through bar over a list of dark car photographs is a
/// see-through bar with grey labels on a dark photograph. These tests hold the
/// tint to the worst thing that can scroll underneath.
void main() {
  double luminance(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  Color over(Color top, Color under) => Color.from(
        alpha: 1,
        red: top.r * top.a + under.r * (1 - top.a),
        green: top.g * top.a + under.g * (1 - top.a),
        blue: top.b * top.a + under.b * (1 - top.a),
      );

  group('text on glass stays readable over the worst background', () {
    // Light glass is worst over black (a dark car photo), dark glass over
    // white. Blur only averages what is there; a large enough black area is
    // still black after it.
    for (final (name, palette, bar, panel, worst) in [
      ('light', AppPalette.light, Glass.surfaceAlphaLight,
          Glass.panelAlphaLight, Colors.black),
      ('dark', AppPalette.dark, Glass.surfaceAlphaDark, Glass.panelAlphaDark,
          Colors.white),
    ]) {
      final barGround = over(palette.surface.withValues(alpha: bar), worst);
      final panelGround = over(palette.surface.withValues(alpha: panel), worst);

      test('$name bar: labels and titles (textPrimary)', () {
        expect(contrast(palette.textPrimary, barGround),
            greaterThanOrEqualTo(4.5));
      });
      test('$name bar: grey or green ink would NOT be readable', () {
        // Why the bars use textPrimary only. If this ever passes, the bar
        // has become opaque enough that it is no longer really glass.
        expect(contrast(palette.textMuted, barGround), lessThan(4.5));
      });
      test('$name panel: secondary text (textMuted) and green ink', () {
        expect(contrast(palette.textMuted, panelGround),
            greaterThanOrEqualTo(4.5));
        expect(contrast(palette.tealText2, panelGround),
            greaterThanOrEqualTo(4.5));
      });
    }

    test('the selected tab: white icon on its filled pill', () {
      for (final p in [AppPalette.light, AppPalette.dark]) {
        expect(contrast(p.onBrand, p.tealFill), greaterThanOrEqualTo(4.5));
      }
    });

    test('smoked glass on a photo is no lighter than the chip it replaced', () {
      // PhotoChip's scrim was measured at 5.7:1 over a white photo. Glass may
      // add blur and a rim; it may not take darkness away.
      expect(Glass.smokeAlpha, greaterThanOrEqualTo(PhotoChip.scrimAlpha));
      final ground = over(PhotoChip.scrim(Glass.smokeAlpha), Colors.white);
      expect(contrast(Colors.white, ground), greaterThanOrEqualTo(4.5));
    });
  });

  Widget host({required bool highContrast, required Widget child}) =>
      MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('real glass blurs what is behind it', (tester) async {
    await tester.pumpWidget(host(
      highContrast: false,
      child: const Glass(child: SizedBox(width: 100, height: 40)),
    ));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('high contrast: the same surface, solid', (tester) async {
    await tester.pumpWidget(host(
      highContrast: true,
      child: const Glass(child: SizedBox(width: 100, height: 40)),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
    final box = tester
        .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(Glass), matching: find.byType(DecoratedBox)))
        .first;
    expect((box.decoration as BoxDecoration).color, AppPalette.light.surface,
        reason: 'fully opaque, not the translucent tint');
  });

  testWidgets('the navigation bar is glass, and floats', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppPalette.light]),
      home: Scaffold(
        bottomNavigationBar: AppNavBar(
          tabs: const [
            NavTab('/a', Icons.home_outlined, Icons.home, 'בית'),
            NavTab('/b', Icons.person_outline, Icons.person, 'פרופיל'),
          ],
          currentIndex: 0,
          onSelected: (_) {},
        ),
      ),
    ));
    expect(find.descendant(of: find.byType(AppNavBar), matching: find.byType(Glass)),
        findsOneWidget);

    // Inset from the screen's sides — floating, not a full-width strip.
    final bar = tester.getRect(find.byType(Glass));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(bar.left, greaterThan(screen.left));
    expect(bar.right, lessThan(screen.right));
    expect(bar.bottom, lessThan(screen.bottom));
  });

  group('pages under the bar can still reach their last row', () {
    // The shell extends its body behind the bar. A scroll view that did not
    // add the bar's height would end with its last card underneath it.
    final shell = File('lib/presentation/widgets/buyer_shell.dart').readAsStringSync();

    test('the buyer shell runs the page under the bar', () {
      expect(shell, contains('extendBody: true'));
    });

    for (final path in [
      'lib/presentation/widgets/car_card_widget.dart',
      'lib/presentation/screens/buyer/garage_screen.dart',
      'lib/presentation/screens/buyer/fuel_stations_screen.dart',
      'lib/presentation/screens/shared/chat_list_screen.dart',
      'lib/presentation/screens/shared/profile_screen.dart',
    ]) {
      test(path.split('/').last, () {
        expect(File(path).readAsStringSync(), contains('navClearance(context)'));
      });
    }

    test('the publish button is lifted above the bar', () {
      // A nested Scaffold under an extended body puts its button at the very
      // bottom, behind the glass. It happened: the button vanished.
      final home =
          File('lib/presentation/screens/buyer/home_screen.dart').readAsStringSync();
      final fab = home.substring(home.indexOf('floatingActionButton:'));
      expect(fab.substring(0, 200), contains('navClearance(context)'));
    });

    test('no tab screen swallows the clearance in a bottom SafeArea', () {
      // SafeArea consumes the padding the shell hands down, which silently
      // turns the glass back into a solid strip with nothing behind it.
      for (final path in [
        'lib/presentation/screens/buyer/home_screen.dart',
        'lib/presentation/screens/buyer/garage_screen.dart',
        'lib/presentation/screens/shared/chat_list_screen.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, contains('bottom: false'), reason: path);
      }
    });
  });

  test('the map credit stays below a glass title bar', () {
    // Required by the ODbL to be visible. With the map running under the
    // bar, a credit at the top would sit behind the title.
    final src =
        File('lib/presentation/widgets/map_attribution.dart').readAsStringSync();
    expect(src, contains('MediaQuery.paddingOf(context).top'));
  });

  test('forms and notices were left solid', () {
    // Glass is for what floats over content. The filter sheet is a form.
    final filters =
        File('lib/presentation/widgets/search_filter_sheet.dart').readAsStringSync();
    expect(filters.contains('Glass('), isFalse);
  });
}
