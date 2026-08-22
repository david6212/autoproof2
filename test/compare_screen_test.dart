import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/utils/car_compare.dart';
import 'package:bonnetcheck/data/models/car_model.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/presentation/providers/compare_provider.dart';
import 'package:bonnetcheck/presentation/providers/gov_api_provider.dart';
import 'package:bonnetcheck/presentation/screens/buyer/compare_screen.dart';

/// Three columns of numbers on a phone is the tightest layout in the app, and
/// the one place where a column that does not fit destroys the whole point of
/// the screen. Nothing here judges whether it looks good — that is still the
/// user's call — but an overflow, a lost column or a missing row is measurable.
void main() {
  CarModel car(String id, {double price = 100000, int km = 60000}) => CarModel(
        id: id,
        plate: '1111111$id'.padRight(8, '0').substring(0, 8),
        make: 'מאזדה',
        model: 'CX-5',
        year: 2019,
        price: price,
        km: km,
        hand: 2,
        area: 'תל אביב',
        sellerId: 's',
        status: CarStatus.active,
        photos: const [],
        reasonForSelling: '',
        createdAt: DateTime(2026, 1, 1),
        fuel: 'בנזין',
        color: 'לבן',
      );

  Widget host(
    List<CarModel> cars, {
    double width = 390,
    double textScale = 1.0,
    GovData? Function(String plate)? lookup,
  }) {
    return ProviderScope(
      overrides: [
        compareSelectionProvider.overrideWith((ref) {
          final s = CompareSelection();
          for (final c in cars) {
            s.toggle(c);
          }
          return s;
        }),
        // No network in a widget test: without this the real provider would
        // reach for data.gov.il and the table would render mid-request.
        govDataForPlateProvider
            .overrideWith((ref, plate) => lookup?.call(plate)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Center(
              child: SizedBox(
                width: width,
                height: 780,
                child: const CompareScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The sections below the fold are not built until scrolled to, so anything
  /// past the first screen has to be reached before it can be asserted on.
  Future<void> scrollTo(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(target, 200,
        scrollable: find.byType(Scrollable).last);
  }

  Future<void> settle(WidgetTester t) async {
    // Not pumpAndSettle: the loading bar animates forever, so settling would
    // time out rather than fail for a real reason.
    await t.pump();
    await t.pump();
  }

  testWidgets('three columns on a 320px phone lay out without overflowing',
      (t) async {
    await t.pumpWidget(host([car('a'), car('b'), car('c')], width: 320));
    await settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('two columns fit a phone with room to spare', (t) async {
    await t.pumpWidget(host([car('a'), car('b')], width: 360));
    await settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('no overflow at the largest text scale the app supports',
      (t) async {
    for (final scale in [1.0, 1.3, 1.6]) {
      await t.pumpWidget(
          host([car('a'), car('b'), car('c')], width: 360, textScale: scale));
      await settle(t);
      expect(t.takeException(), isNull, reason: 'text scale $scale');
    }
  });

  testWidgets('every picked car gets its own column', (t) async {
    await t.pumpWidget(host([
      car('a', price: 120000),
      car('b', price: 90000),
      car('c', price: 105000),
    ]));
    await settle(t);

    // One price cell per car, none of them dropped off the table.
    for (final price in ['₪120,000', '₪90,000', '₪105,000']) {
      expect(find.text(price), findsOneWidget, reason: price);
    }
  });

  testWidgets('the row labels are present so a column can be read', (t) async {
    await t.pumpWidget(host([car('a'), car('b')]));
    await settle(t);

    for (final label in ['מחיר', 'קילומטראז\'', 'יד', 'שנת ייצור']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the official section is shown even with nothing on file',
      (t) async {
    // Dashes rather than a missing section — "checked, nothing found" and
    // "never looked" must not look the same.
    await t.pumpWidget(host([car('a'), car('b')]));
    await settle(t);

    await scrollTo(t, find.text('רשומות משרד התחבורה'));
    expect(find.text('רשומות משרד התחבורה'), findsOneWidget);
    expect(find.text('מידע רשמי · משרד התחבורה'), findsOneWidget);
    // It says so, rather than leaving nine rows of dashes to be interpreted.
    expect(find.textContaining('לא נמצאו רשומות'), findsOneWidget);
  });

  testWidgets('official records fill in when the registry answers', (t) async {
    await t.pumpWidget(host(
      // Against a 143,851 official reading: the first car claims less (the
      // rollback signal), the second has simply kept driving since the test.
      [car('a', km: 41000), car('b', km: 200000)],
      lookup: (plate) => GovData(
        plate: plate,
        make: 'מאזדה',
        commercialName: 'CX-5',
        model: 'CX-5',
        year: 2019,
        color: 'לבן',
        fuelType: 'בנזין',
        ownershipType: 'פרטי',
        trim: '',
        lastTestDate: null,
        licenseExpiry: null,
        safetyRating: null,
        chassis: '',
        pollutionGroup: '',
        engineModel: '',
        frontTire: '',
        rearTire: '',
        firstOnRoad: '',
        lastTestKm: 143851,
        structuralChange: false,
        colorChanged: false,
        tireChanged: false,
        originality: 'פרטי',
        firstRegistration: '',
        recalls: const [],
        offRoad: false,
        offRoadDate: '',
        tozeretCd: '',
        degemCd: '',
      ),
    ));
    await settle(t);

    await scrollTo(t, find.text('התאמת ק"מ'));
    // The car listed at 41,000 against a 143,851 official reading is the
    // rollback case, and it has to be visible on the table itself.
    expect(find.textContaining('נמוך ב-102,851'), findsOneWidget);
    expect(find.text('תואם'), findsOneWidget);
  });

  testWidgets('the screen states that it does not rank the cars', (t) async {
    await t.pumpWidget(host([car('a'), car('b')]));
    await settle(t);

    await scrollTo(t, find.textContaining('לא מדרגת רכבים'));
    expect(find.textContaining('לא מדרגת רכבים'), findsOneWidget);
  });

  testWidgets('one car is not a comparison', (t) async {
    await t.pumpWidget(host([car('a')]));
    await settle(t);

    expect(find.text('צריך לפחות שני רכבים להשוואה'), findsOneWidget);
    expect(find.text('מחיר'), findsNothing);
  });

  testWidgets('the table survives more rows than the viewport is tall',
      (t) async {
    // Every section rendered at once is well past a phone screen; the body has
    // to scroll vertically while the header stays put.
    await t.pumpWidget(host([car('a'), car('b')], width: 360));
    await settle(t);

    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    await t.drag(list, const Offset(0, -300));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets('the header keeps the cars visible while the rows scroll',
      (t) async {
    await t.pumpWidget(host([car('a'), car('b')], width: 360));
    await settle(t);

    final titles = find.text('מאזדה CX-5');
    expect(titles, findsNWidgets(2));
    final before = t.getRect(titles.first);

    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pump();

    // Same place after scrolling — the header is outside the scrolling list.
    expect(t.getRect(titles.first), before);
  });

  testWidgets('maxCompareCars is what the screen was laid out for', (t) async {
    // The column width was chosen against this number. If it changes, the
    // 320px case above is no longer the tight one that was measured.
    expect(maxCompareCars, 3);
  });
}
