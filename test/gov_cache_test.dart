import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bonnetcheck/core/constants/app_strings.dart';
import 'package:bonnetcheck/data/sources/local/gov_cache.dart';

/// Reading the government datasets politely, and saying what they are.
///
/// Two obligations that come with using data.gov.il, and David asked for both
/// after reading the state's own terms: do not flood the servers, and do not
/// let a reader mistake an open dataset for an official confirmation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the cache', () {
    test('a fresh entry is served without asking the network', () async {
      final cache = GovCache(prefs: await SharedPreferences.getInstance());
      await cache.write('k', [
        {'name': 'תחנה'}
      ]);

      final fresh = await cache.read('k', const Duration(hours: 1));
      expect(fresh, isA<List<dynamic>>());
      expect((fresh! as List).first['name'], 'תחנה');
    });

    test('a stale entry is not served as fresh', () async {
      final cache = GovCache(prefs: await SharedPreferences.getInstance());
      await cache.write('k', [1, 2, 3]);

      expect(await cache.read('k', Duration.zero), isNull,
          reason: 'anything older than the ttl must go back to the network');
    });

    test('but it is still there when the network has just failed', () async {
      // The fallback that matters on a phone with no signal: yesterday's
      // station list beats an empty map.
      final cache = GovCache(prefs: await SharedPreferences.getInstance());
      await cache.write('k', [1, 2, 3]);

      expect(await cache.read('k', Duration.zero), isNull);
      expect(await cache.readStale('k'), [1, 2, 3]);
    });

    test('it records when the copy was taken', () async {
      final cache = GovCache(prefs: await SharedPreferences.getInstance());
      await cache.write('k', const []);
      final at = await cache.writtenAt('k');
      expect(at, isNotNull);
      expect(DateTime.now().difference(at!).inSeconds, lessThan(5));
    });

    test('corrupt content is ignored, not thrown', () async {
      // A half-written entry must not be able to stop the app from starting.
      SharedPreferences.setMockInitialValues({'gov_cache_k': 'not json {'});
      final cache = GovCache(prefs: await SharedPreferences.getInstance());
      expect(await cache.read('k', const Duration(hours: 1)), isNull);
      expect(await cache.readStale('k'), isNull);
    });

    test('clearing removes what this class wrote and nothing else', () async {
      SharedPreferences.setMockInitialValues({'flutter.other': 'keep'});
      final prefs = await SharedPreferences.getInstance();
      final cache = GovCache(prefs: prefs);
      await cache.write('k', const []);

      await cache.clear();

      expect(prefs.getString('gov_cache_k'), isNull);
      // The plugin stores under a `flutter.` prefix and strips it on read,
      // so this is the same key the mock was seeded with.
      expect(prefs.getString('other'), 'keep');
    });

    test('the ttls match how fast each dataset actually moves', () {
      // Stated as a test because a cache is a promise about staleness, and the
      // numbers are the promise.
      expect(GovCache.fuelStationsTtl, const Duration(hours: 24));
      expect(GovCache.inspectionCentersTtl, const Duration(days: 7));
      expect(GovCache.refineryPricesTtl, const Duration(hours: 12));
    });
  });

  group('what is deliberately NOT cached', () {
    test('a plate lookup never touches the cache', () {
      // Keeping registry answers about cars somebody browsed would build a
      // list of plates on the device. This app has kept plates out of
      // everywhere else; the cache is not where that starts.
      final repo = File('lib/data/repositories/gov_api_repository.dart')
          .readAsStringSync();
      final lookup = repo.substring(repo.indexOf('Future<GovData> lookupPlate'));
      final body = lookup.substring(0, lookup.indexOf('\n  }\n'));
      expect(body.contains('_cache'), isFalse);
      expect(body.contains('_dataset'), isFalse);
    });

    test('and the reason is written where the next reader will look', () {
      final cache = File('lib/data/sources/local/gov_cache.dart').readAsStringSync();
      expect(cache, contains('NOT cached: a plate lookup'));
    });
  });

  group('the requests themselves', () {
    final service =
        File('lib/data/sources/remote/gov_api_service.dart').readAsStringSync();

    test('go out one at a time, with a gap', () {
      expect(service, contains('static Future<void> _queue'));
      expect(service, contains('static const minGap'));
    });

    test('and a failed request does not stall every later one', () {
      // The trap in a promise chain: one rejection and the queue never
      // advances again, so the app stops talking to the registry until it is
      // restarted.
      expect(service, contains('_queue = next.catchError'));
    });
  });

  group('what the app says the registry data is', () {
    test('the note says open data, incomplete, not an official confirmation',
        () {
      for (final phrase in [
        'מאגר ממשלתי פתוח',
        'חסר',
        'אינו ייעוץ משפטי',
        'אינו אישור רשמי',
      ]) {
        expect(AppStrings.registrySourceNote, contains(phrase), reason: phrase);
      }
    });

    test('it is under the figures, not only in the terms', () {
      final card = File('lib/presentation/widgets/gov_data_card_widget.dart')
          .readAsStringSync();
      expect(card, contains('AppStrings.registrySourceNote'));
    });

    test('and the terms say it too', () {
      final legal =
          File('lib/core/constants/legal_docs.dart').readAsStringSync();
      expect(legal, contains('מאגרי מידע ממשלתיים פתוחים'));
      expect(legal, contains('אישור רשמי'));
    });
  });
}
