import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/presentation/providers/cars_provider.dart';
import 'package:bonnetcheck/presentation/screens/buyer/home_screen.dart';

/// Home's header is now the tallest fixed block in the app: brand row, search
/// card, three filter shortcuts. Everything below it — the cars, which are the
/// reason anyone opens the app — lives in what is left.
///
/// Nothing here judges whether it looks right. It measures that the header
/// fits, that it does not eat the screen, and that the shortcuts say what the
/// filters actually are.
void main() {
  CarModel car(String id) => CarModel(
        id: id,
        plate: '1111111$id',
        make: 'מאזדה',
        model: 'CX-5',
        year: 2019,
        price: 132000,
        km: 92000,
        hand: 2,
        area: 'תל אביב',
        sellerId: 's',
        status: CarStatus.active,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime(2026, 1, 1),
      );

  Widget host({
    CarFilters filters = const CarFilters(),
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        activeCarsProvider.overrideWith((ref) => Stream.value([car('a')])),
        carFiltersProvider.overrideWith((ref) => filters),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const HomeScreen(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the header lays out on a small phone', (t) async {
    await t.pumpWidget(host(size: const Size(320, 640)));
    await t.pump();
    expect(t.takeException(), isNull);

    expect(find.text('חיפוש רכב'), findsOneWidget);
    expect(find.text('מצאו את הרכב הבא שלכם, ללא הפתעות'), findsOneWidget);
  });

  testWidgets('three filter shortcuts, on one row', (t) async {
    await t.pumpWidget(host());
    await t.pump();

    for (final label in ['אזור', 'מחיר', 'שנה']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final tops = ['אזור', 'מחיר', 'שנה']
        .map((l) => t.getRect(find.text(l)).top)
        .toList();
    for (final top in tops) {
      expect(top, closeTo(tops.first, 0.5), reason: 'shortcuts wrapped: $tops');
    }
  });

  testWidgets('a shortcut shows the filter it is holding', (t) async {
    // An empty shortcut says what it filters; a set one says what it is set
    // to. Otherwise the row reads as three buttons that never respond.
    await t.pumpWidget(host(
      filters: const CarFilters(area: 'חיפה', maxPrice: 150000, minYear: 2018),
    ));
    await t.pump();

    expect(find.text('חיפה'), findsOneWidget);
    expect(find.text('עד 150 אלף'), findsOneWidget);
    expect(find.text('מ-2018'), findsOneWidget);
    // …and the generic labels are gone, so nothing is stated twice.
    expect(find.text('אזור'), findsNothing);
  });

  testWidgets('the header leaves the cars most of the screen', (t) async {
    // The reference design's home is a search FORM, which is fine when the
    // results are a page away. This one is browse-first: if the header takes
    // half the screen the listings stop being the subject.
    await t.pumpWidget(host());
    await t.pump();

    final header = t.getRect(find.text('חיפוש רכב'));
    final card = t.getRect(find.byType(HomeScreen));
    expect(header.top, lessThan(200), reason: 'search card is near the top');

    // Whatever the header ends up costing, over half the viewport is left.
    final shortcutBottom = t.getRect(find.text('אזור')).bottom;
    expect(shortcutBottom, lessThan(card.height * 0.5),
        reason: 'header ends at $shortcutBottom of ${card.height}');
  });

  testWidgets('it survives the largest text scale', (t) async {
    for (final scale in [1.0, 1.3, 1.6]) {
      await t.pumpWidget(host(size: const Size(320, 700), textScale: scale));
      await t.pump();
      expect(t.takeException(), isNull, reason: 'text scale $scale');
    }
  });

  testWidgets('the header tint is a token, not a hardcoded colour', (t) async {
    await t.pumpWidget(host());
    await t.pump();

    final tinted = t.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      return c.color == AppPalette.light.headerTint ||
          (d is BoxDecoration && d.color == AppPalette.light.headerTint);
    });
    expect(tinted, isNotEmpty, reason: 'the header should use headerTint');
  });
}
