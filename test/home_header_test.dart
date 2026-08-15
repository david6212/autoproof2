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

  testWidgets('nothing filtered, nothing to summarise', (t) async {
    // The row is a summary of an active search, not a set of controls. Three
    // empty buttons that all opened the same sheet were three ways of saying
    // "no filters", above a list already showing everything.
    await t.pumpWidget(host());
    await t.pump();

    expect(find.text('חיפוש רכב'), findsOneWidget, reason: 'card is there');
    for (final label in ['אזור', 'מחיר', 'שנה']) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('each active filter appears, saying what it is set to',
      (t) async {
    await t.pumpWidget(host(
      filters: const CarFilters(
        area: 'חיפה',
        maxPrice: 150000,
        minYear: 2018,
        maxKm: 90000,
        colorCat: 'כסף',
      ),
    ));
    await t.pump();

    expect(find.text('חיפה'), findsOneWidget);
    expect(find.text('עד ₪150,000'), findsOneWidget);
    expect(find.text('משנת 2018'), findsOneWidget);
    expect(find.text('עד 90,000 ק"מ'), findsOneWidget);
    expect(find.text('כסף'), findsOneWidget);
  });

  testWidgets('the summary wraps rather than overflowing', (t) async {
    // Every filter at once on the narrowest phone. A Row would silently run
    // off the edge; this has to move to another line.
    await t.pumpWidget(host(
      size: const Size(320, 800),
      filters: const CarFilters(
        area: 'ראשון לציון',
        make: 'מאזדה',
        model: 'CX-5',
        maxPrice: 150000,
        minYear: 2018,
        maxKm: 90000,
        fuel: 'היברידי',
        colorCat: 'כסף',
        maxHand: 2,
        ownership: 'פרטית',
        drivetrain: '4X4',
        minSeats: 5,
        engineRange: '1600-2000',
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('the header leaves the cars most of the screen', (t) async {
    // The reference design's home is a search FORM, which is fine when the
    // results are a page away. This one is browse-first: if the header takes
    // half the screen the listings stop being the subject.
    //
    // Measured with filters ACTIVE, which is the tallest the header ever gets.
    await t.pumpWidget(host(
      filters: const CarFilters(area: 'חיפה', maxPrice: 150000),
    ));
    await t.pump();

    final screen = t.getRect(find.byType(HomeScreen));
    expect(t.getRect(find.text('חיפוש רכב')).top, lessThan(200),
        reason: 'the search card is near the top');

    final headerBottom = t.getRect(find.text('חיפה')).bottom;
    expect(headerBottom, lessThan(screen.height * 0.5),
        reason: 'header ends at $headerBottom of ${screen.height}');
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
