import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/data/sources/remote/gov_api_service.dart';
import 'package:bonnetcheck/presentation/providers/gov_api_provider.dart';
import 'package:bonnetcheck/presentation/screens/buyer/check_plate_screen.dart';

/// Checking a car that is not yours and not listed here.
///
/// The app's one capability that depends on nothing we publish — and until
/// 27/09 the only way to reach it was "הוסף רכב" in the garage, which asks the
/// reader to declare the car is theirs. A buyer checking a stranger's car had
/// to lie to a form to get an answer.
void main() {
  Widget host(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      );

  GovData answer() => GovData.fromApi({
        'tozeret_nm': 'מאזדה',
        'kinuy_mishari': 'CX-5',
        'shnat_yitzur': 2017,
        'mispar_rechev': 12345678,
      });

  testWidgets('a bad plate is refused before anything is asked',
      (tester) async {
    var asked = 0;
    await tester.pumpWidget(host(
      const CheckPlateScreen(),
      overrides: [
        govDataForPlateProvider.overrideWith((ref, plate) async {
          asked++;
          return answer();
        }),
      ],
    ));

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('בדקו'));
    await tester.pump();

    expect(find.textContaining('7 או 8 ספרות'), findsOneWidget);
    expect(asked, 0, reason: 'no request should leave for an impossible plate');
  });

  testWidgets('a good plate shows what the registry answered', (tester) async {
    await tester.pumpWidget(host(
      const CheckPlateScreen(),
      overrides: [
        govDataForPlateProvider.overrideWith((ref, plate) async => answer()),
      ],
    ));

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.tap(find.text('בדקו'));
    await tester.pumpAndSettle();

    expect(find.textContaining('מאזדה'), findsWidgets);
    // The obligation that travels with the data, on the same screen.
    expect(find.textContaining('מאגר ממשלתי פתוח'), findsWidgets);
  });

  testWidgets('a plate the registry does not know is an answer, not an error',
      (tester) async {
    await tester.pumpWidget(host(
      const CheckPlateScreen(),
      overrides: [
        govDataForPlateProvider.overrideWith((ref, plate) async => null),
      ],
    ));

    await tester.enterText(find.byType(TextField), '87654321');
    await tester.tap(find.text('בדקו'));
    await tester.pumpAndSettle();

    expect(find.textContaining('לא נמצא במרשם'), findsOneWidget);
    expect(find.textContaining('נסו שוב'), findsNothing,
        reason: 'retrying will not make the registry know this car');
  });

  testWidgets('an outage says so, and offers to try again', (tester) async {
    await tester.pumpWidget(host(
      const CheckPlateScreen(),
      overrides: [
        govDataForPlateProvider.overrideWith(
          (ref, plate) async => throw GovApiException('שירות הנתונים אינו זמין'),
        ),
      ],
    ));

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.tap(find.text('בדקו'));
    await tester.pumpAndSettle();

    expect(find.textContaining('לא הצלחנו להגיע למרשם'), findsOneWidget);
    expect(find.text('נסו שוב'), findsOneWidget);
  });

  group('the plate leaves no trace', () {
    final screen = File('lib/presentation/screens/buyer/check_plate_screen.dart')
        .readAsStringSync();

    test('it is not written anywhere', () {
      // Comment-stripped: the file explains in its own doc comment that the
      // plate is kept out of the cache, and naming `GovCache` there is the
      // explanation, not a use of it.
      final code = screen
          .split(RegExp('[\r\n]+'))
          .where((l) => !l.trimLeft().startsWith('//') &&
              !l.trimLeft().startsWith('///'))
          .join(' ');
      for (final sink in ['setString', 'Firestore', 'collection(', 'GovCache']) {
        expect(code.contains(sink), isFalse, reason: sink);
      }
    });

    test('and analytics is told a lookup happened, not which car', () {
      expect(screen, contains('vehicleLookup()'));
      expect(screen.contains('vehicleLookup(plate'), isFalse);

      final analytics =
          File('lib/presentation/providers/analytics_provider.dart')
              .readAsStringSync();
      expect(analytics, contains('Future<void> vehicleLookup() =>'),
          reason: 'the method must stay argument-free');
    });

    test('and the screen says so where the reader can see it', () {
      expect(screen, contains('ואינו נשמר'));
    });
  });

  test('a guest can reach it — the route is not behind the account guard', () {
    // The whole point: no account, no listing, no ownership claim.
    final router = File('lib/app/router.dart').readAsStringSync();
    expect(router, contains("path: '/check'"));

    final guard = router.substring(0, router.indexOf("path: '/check'"));
    expect(guard.contains("'/check'"), isFalse,
        reason: '/check must not be listed among the routes needing an account');
  });

  test('Home offers it above the feed', () {
    // The feed is what the app hopes to have; the registry is what it has.
    final home = File('lib/presentation/screens/buyer/home_screen.dart')
        .readAsStringSync();
    expect(home, contains('_CheckPlateRow'));
    // Where it is RENDERED, not where the class happens to be declared: the
    // row is built inside the header, which is above the list in the tree.
    final built = home.indexOf('const _CheckPlateRow(),');
    expect(built, greaterThan(-1));
    expect(built, lessThan(home.indexOf('class _CheckPlateRow')));
  });
}
