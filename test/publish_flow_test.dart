import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/providers/create_listing_provider.dart';
import 'package:bonnetcheck/presentation/providers/seller_verification_provider.dart';

/// Publishing used to take eight screens and two progress bars.
///
/// Three of them — "מי אתה?", the ownership check, and a success page that
/// only reported the first two — existed because a router redirect refused to
/// open the publish flow until they were done. So a seller met a wall of
/// verification before seeing one screen of their own listing, and crossed two
/// separate bars that both counted "step 1 of 3".
///
/// It is one flow of four steps now: the car, the price, the photos, and
/// publishing. These pin the parts of that which are easy to undo by accident.
void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('the step machine', () {
    test('runs from the car to publishing and stops there', () {
      final c = container();
      final notifier = c.read(createListingControllerProvider.notifier);

      expect(c.read(createListingControllerProvider).step, 0);
      for (var i = 0; i < 10; i++) {
        notifier.next();
      }
      expect(c.read(createListingControllerProvider).step,
          CreateListingController.lastStep);
      expect(CreateListingController.lastStep, 3,
          reason: 'four steps, and the progress bar is told the same number');
    });

    test('back stops at the first step rather than leaving the flow', () {
      final c = container();
      final notifier = c.read(createListingControllerProvider.notifier);
      notifier.next();
      notifier.back();
      notifier.back();
      expect(c.read(createListingControllerProvider).step, 0);
    });
  });

  group('the first step is not done until the registry answered', () {
    test('no car, no continue — with or without a name', () {
      final c = container();
      final notifier = c.read(createListingControllerProvider.notifier);

      expect(notifier.carValid(needsName: false), isFalse);
      c.read(sellerVerificationControllerProvider.notifier).setName('דוד');
      expect(notifier.carValid(needsName: true), isFalse,
          reason: 'a name is not a substitute for a car in the registry');
    });
  });

  group('publishing still refuses what the redirect used to refuse', () {
    test('a listing with no verified car does not go out', () async {
      final c = container();
      final notifier = c.read(createListingControllerProvider.notifier);

      await notifier.publish();

      final state = c.read(createListingControllerProvider);
      expect(state.publishedId, isNull);
      expect(state.error, isNotNull);
    });
  });

  group('the three screens the flow absorbed', () {
    test('are gone, along with the redirect that required them', () {
      for (final name in const [
        'verify_role_screen.dart',
        'verify_plate_screen.dart',
        'verify_success_screen.dart',
      ]) {
        expect(
          File('lib/presentation/screens/verify/$name').existsSync(),
          isFalse,
          reason: '$name was replaced by step 1 of the publish flow',
        );
      }

      // The phone step survives as its own screen — it is reached from the
      // last step, and it is the one check that cannot be folded into a form.
      expect(
        File('lib/presentation/screens/verify/verify_phone_screen.dart')
            .existsSync(),
        isTrue,
      );

      final router = File('lib/app/router.dart').readAsStringSync();
      expect(router.contains("'/verify/role'"), isFalse);
      expect(router.contains("'/verify/plate'"), isFalse);
      expect(router.contains("'/verify/success'"), isFalse);
    });

    test('nothing still links to a route that no longer exists', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final dead in const [
            '/verify/role',
            '/verify/plate',
            '/verify/success',
          ]) {
            if (lines[i].contains(dead)) offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('the way out', () {
    final source =
        File('lib/presentation/screens/seller/create_listing_screen.dart')
            .readAsStringSync();

    test('the first step offers an exit, not a dead corner', () {
      // The leading control used to be null on step 1, which means "whatever
      // Flutter decides": a back arrow when the screen had been pushed, and
      // nothing at all when it was reached from a tab. A form with no way out
      // is a trap, and the way out of a listing form is the listings.
      expect(source, contains('popOrHome(context)'));
      expect(source, contains('חזרה לרכבים למכירה'));
      expect(source.contains('leading: state.step > 0'), isFalse);
    });

    test('the system back walks the steps instead of leaving the flow', () {
      // Without this, one swipe from step 4 drops three filled-in steps.
      expect(source, contains('PopScope'));
      expect(source, contains('canPop: onFirstStep'));
    });
  });
}
