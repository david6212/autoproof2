import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bonnetcheck/presentation/providers/onboarding_seen_provider.dart';

/// The three opening screens run once per install, not once per launch.
///
/// Until 25/08 the splash sent anyone without an account to `/onboarding`, and
/// a guest never has an account. So somebody browsing without signing up met
/// three slides, then a login wall, then had to tap "גלוש בלי להתחבר" — every
/// time they opened the app. Five steps to reach a listing, forever.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install has not seen them', () async {
    expect(await OnboardingSeen.get(), isFalse);
  });

  test('once marked, it stays marked', () async {
    await OnboardingSeen.mark();
    expect(await OnboardingSeen.get(), isTrue);
  });

  test('the key is versioned, so rewritten slides can be shown again', () {
    // Without the suffix, an install that has seen ANY onboarding would never
    // see another — including one worth showing.
    final src =
        File('lib/presentation/providers/onboarding_seen_provider.dart')
            .readAsStringSync();
    expect(src, contains("_key = 'onboarding_seen_v1'"));
  });

  test('the splash checks it before routing a guest', () async {
    final src = File('lib/presentation/screens/auth/splash_screen.dart')
        .readAsStringSync();

    expect(src, contains('await OnboardingSeen.get()'));
    expect(src, contains("context.go(seen ? '/home' : '/onboarding')"));
  });

  test('both exits from the slides mark them seen', () async {
    // Finishing and skipping alike. A skip that did not mark would bring the
    // slides back on the next launch for the person who most clearly said
    // they did not want them.
    final src = File('lib/presentation/screens/auth/onboarding_screen.dart')
        .readAsStringSync();
    expect('OnboardingSeen.mark()'.allMatches(src).length, 2);
  });

  test('skipping goes to the marketplace, not to the login wall', () async {
    // Someone who taps "דלג" has said they want to look around. Answering
    // that with a sign-in form answers a different question.
    final src = File('lib/presentation/screens/auth/onboarding_screen.dart')
        .readAsStringSync();
    final skip = src.indexOf('// Skipping goes to the marketplace');
    expect(skip, greaterThan(-1));
    expect(src.substring(skip, skip + 400), contains("context.go('/home')"));
  });
}
