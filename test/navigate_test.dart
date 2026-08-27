import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/widgets/navigate_sheet.dart';

/// Taking somebody to a place, rather than showing them where it is.
///
/// Every map screen already knew a destination and still made the reader type
/// it into another app: the links were Google Maps *search* URLs, which drop a
/// pin and leave the "directions" tap to you. And there was no Waze anywhere,
/// which in Israel is the app most people actually drive with.
void main() {
  group('what gets handed to the navigation app', () {
    test('real coordinates are used exactly', () {
      // Tel Aviv. An exact destination beats a search every time: two garages
      // can share a name, a coordinate pair cannot.
      final r = NavigateSheet.destinationFor(
        lat: 32.0853,
        lng: 34.7818,
        query: 'מוסך כלשהו תל אביב',
      );
      expect(r.isCoords, isTrue);
      expect(r.destination, '32.0853,34.7818');
    });

    test('0,0 is refused and the name is used instead', () {
      // THE TRAP. `addCommunityPlace` stores lat: 0, lng: 0 — the add-place
      // screen says outright that it does not capture a location yet. Zero is
      // a perfectly valid coordinate pair in the Atlantic off West Africa, so
      // nothing would look broken: the sheet would open, Waze would open, and
      // the driver would be given a route out to sea.
      final r = NavigateSheet.destinationFor(
        lat: 0,
        lng: 0,
        query: 'מוסך הכרמל חיפה',
      );
      expect(r.isCoords, isFalse);
      expect(r.destination, 'מוסך הכרמל חיפה');
    });

    test('coordinates outside Israel are refused too', () {
      // Not only 0,0. A bad geocode or a swapped lat/lng lands somewhere just
      // as confidently wrong, and the same rule catches it.
      for (final pair in const [
        (51.5, -0.12), // London
        (34.7818, 32.0853), // Tel Aviv with lat and lng the wrong way round
      ]) {
        final r = NavigateSheet.destinationFor(
          lat: pair.$1,
          lng: pair.$2,
          query: 'תחנת דלק אשדוד',
        );
        expect(r.isCoords, isFalse, reason: '${pair.$1},${pair.$2}');
      }
    });

    test('a missing coordinate falls back rather than throwing', () {
      final r = NavigateSheet.destinationFor(
        lat: null,
        lng: null,
        query: '  מכון בדיקה נתניה  ',
      );
      expect(r.isCoords, isFalse);
      expect(r.destination, 'מכון בדיקה נתניה', reason: 'and it is trimmed');
    });
  });

  group('the sheet itself', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => NavigateSheet.show(
                context,
                lat: 32.0853,
                lng: 34.7818,
                query: 'תחנה',
                label: 'פז תל אביב',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers Waze first', (tester) async {
      await pump(tester);

      final waze = tester.getTopLeft(find.text('Waze')).dy;
      final google = tester.getTopLeft(find.text('Google Maps')).dy;
      expect(waze, lessThan(google),
          reason: 'in Israel Waze is what most drivers have in the car');
    });

    testWidgets('names the destination before any app opens', (tester) async {
      // So a mistap on a dense list is obvious while it can still be undone.
      await pump(tester);
      expect(find.text('פז תל אביב'), findsOneWidget);
    });

    testWidgets('can be dismissed without navigating anywhere',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('ביטול'));
      await tester.pumpAndSettle();
      expect(find.text('Waze'), findsNothing);
    });

    testWidgets('Apple Maps is not offered on Android', (tester) async {
      await pump(tester);
      expect(find.text('Apple Maps'), findsNothing,
          reason: 'the test host is not iOS');
    });
  });

  group('every place in the app can be navigated to', () {
    test('all three screens use the shared sheet', () {
      for (final path in const [
        'lib/presentation/screens/buyer/fuel_stations_screen.dart',
        'lib/presentation/screens/buyer/inspectors_screen.dart',
        'lib/presentation/screens/places/place_detail_screen.dart',
      ]) {
        expect(File(path).readAsStringSync(), contains('NavigateSheet.show('),
            reason: '$path shows a place and must be able to take you there');
      }
    });

    test('nothing still links to a Maps *search* instead of directions', () {
      // The old links opened a pin, not a route. Leaving one behind would mean
      // one screen quietly does less than the others.
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        expect(entity.readAsStringSync().contains('maps/search/?api=1'), isFalse,
            reason: '${entity.path} still opens a pin rather than a route');
      }
    });
  });
}
