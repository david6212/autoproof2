import 'package:flutter_test/flutter_test.dart';

import 'package:otov/data/models/fuel_station.dart';
import 'package:otov/presentation/widgets/map_cluster.dart';

/// Fixtures copied verbatim from a live data.gov.il response, including the
/// awkward column names: the coordinate keys contain a space and a full stop,
/// and אורך/רוחב are longitude/latitude — the exact pair that is easy to swap.
Map<String, dynamic> row({
  Object? id = 877,
  String company = 'טן',
  String name = 'ראש פינה',
  String city = 'ראש פינה',
  Object? lon = 35.54895477,
  Object? lat = 32.96887209,
}) =>
    {
      '_id': 1,
      'מס_מינהל_הדלק': id,
      'חברה': company,
      'שם_תחנה': name,
      'כתובת': 'מ.מסחרי סנטר הגליל ראש פינה (מול המשטרה)',
      'רשות_מקומית': city,
      'X': 251730,
      'Y': 763856,
      'נ.צ. אורך': lon,
      'נ.צ. רוחב': lat,
    };

void main() {
  group('parsing', () {
    test('reads a real row, with longitude and latitude the right way round',
        () {
      final s = FuelStation.fromApi(row());
      expect(s.id, '877');
      expect(s.company, 'טן');
      expect(s.city, 'ראש פינה');
      // Israel is ~32.97 N, ~35.55 E. Swapping these puts the pin in Iraq,
      // and every value would still be a perfectly valid double.
      expect(s.lat, closeTo(32.97, 0.01));
      expect(s.lng, closeTo(35.55, 0.01));
      expect(s.plausible, isTrue);
    });

    test('a swapped pair is rejected rather than drawn', () {
      final s = FuelStation.fromApi(row(lon: 32.96887209, lat: 35.54895477));
      expect(s.hasCoords, isTrue, reason: 'both numbers are present…');
      expect(s.plausible, isFalse, reason: '…but 35.5 N is not in Israel');
    });

    test('the two rows with no coordinates survive parsing', () {
      // They are dropped from the map by the repository, not by a crash here.
      final s = FuelStation.fromApi(row(lon: null, lat: null));
      expect(s.hasCoords, isFalse);
      expect(s.plausible, isFalse);
      expect(s.name, isNotEmpty);
    });

    test('a zero coordinate counts as missing, not as the Gulf of Guinea', () {
      final s = FuelStation.fromApi(row(lon: 0, lat: 0));
      expect(s.hasCoords, isFalse);
    });

    test('the operator is not repeated when it is already in the name', () {
      expect(FuelStation.fromApi(row(company: 'פז', name: 'פז חיפה')).displayName,
          'פז חיפה');
      expect(FuelStation.fromApi(row(company: 'טן', name: 'ראש פינה')).displayName,
          'טן ראש פינה');
    });
  });

  group('refinery reference', () {
    test('converts ₪ per kilolitre to ₪ per litre', () {
      final r = FuelReference.fromApi({
        'תאריך': '2026-08-01 00:00:00',
        'מוצר': 'סולר לתחבורה במכלית',
        'יחידת מידה': 'קילו ליטר',
        'מחיר': 3427.4,
      });
      // 3427.4 per 1000 L. Showing the raw figure would claim diesel costs
      // 3,427 shekels a litre; forgetting the divide is the whole risk here.
      expect(r.shekelsPerLitre, closeTo(3.4274, 0.0001));
      expect(r.monthLabel, '08/2026');
    });
  });

  group('clustering, after being made generic', () {
    // The algorithm was verified against the real inspection-centre
    // coordinates for zero overlaps at every zoom. Moving it to a generic
    // class must not have changed what it does.
    List<FuelStation> stations(int n, {double lat = 32.0, double spread = 0}) =>
        [
          for (var i = 0; i < n; i++)
            FuelStation(
              id: '$i',
              company: 'פז',
              name: 'תחנה $i',
              address: '',
              city: 'תל אביב',
              lat: lat + i * spread,
              lng: 34.8 + i * spread,
            ),
        ];

    test('no station is ever lost, at any zoom', () {
      final all = stations(40, spread: 0.02);
      for (final z in [6.0, 8.0, 11.0, 12.0, 14.0, 16.0]) {
        final total = MapCluster.at<FuelStation>(z, all)
            .fold<int>(0, (n, c) => n + c.count);
        expect(total, all.length, reason: 'zoom $z dropped a station');
      }
    });

    test('items without coordinates are skipped, not crashed on', () {
      final all = [
        ...stations(3, spread: 0.05),
        const FuelStation(
            id: 'x', company: 'פז', name: 'ללא נ״צ', address: '', city: 'חיפה'),
      ];
      final total =
          MapCluster.at<FuelStation>(14, all).fold<int>(0, (n, c) => n + c.count);
      expect(total, 3);
    });

    test('below the street zoom a whole town is one node', () {
      // 12 stations in one city, far enough apart that street zoom separates
      // them — city zoom must still collapse them to a single bubble.
      final all = stations(12, spread: 0.03);
      final city = MapCluster.at<FuelStation>(8, all);
      expect(city, hasLength(1));
      expect(city.first.count, 12);
      expect(city.first.label, 'תל אביב');
      expect(MapCluster.at<FuelStation>(16, all).length, greaterThan(1));
    });

    test('identical coordinates collapse instead of stacking invisibly', () {
      final all = stations(5); // spread 0 — all on the same point
      final clusters = MapCluster.at<FuelStation>(16, all);
      expect(clusters, hasLength(1));
      expect(clusters.first.count, 5);
    });

    test('a mixed cluster is labelled as an area, not as one town', () {
      final mixed = [
        ...stations(3),
        const FuelStation(
            id: 'h',
            company: 'דלק',
            name: 'x',
            address: '',
            city: 'רמת גן',
            lat: 32.0001,
            lng: 34.8001),
      ];
      final c = MapCluster.at<FuelStation>(16, mixed).single;
      expect(c.soleCity, isNull);
      expect(c.label, 'אזור תל אביב');
    });
  });

  group('distance formatting', () {
    test('metres below a kilometre, kilometres above', () {
      expect(fmtDistance(820), '820 מ׳');
      expect(fmtDistance(3400), '3.4 ק״מ');
    });
  });
}
