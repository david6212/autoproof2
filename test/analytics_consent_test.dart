import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bonnetcheck/presentation/providers/analytics_consent_provider.dart';
import 'package:bonnetcheck/presentation/providers/analytics_provider.dart';

/// Measurement waits to be asked.
///
/// Before this, opening the site wrote a `_ga` identifier and sent two
/// `collect` calls while the splash screen was still animating — no question
/// asked, no way to withdraw. ePrivacy Art. 5(3) requires prior consent for
/// storing that identifier, GDPR Art. 4(11) requires "a clear affirmative
/// action", and Apple's §5.1.1(ii) requires an accessible way to take it back.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('nothing is allowed before an answer exists', () async {
    final c = container();

    // Still loading — the state that used to be "measure anyway".
    expect(c.read(analyticsAllowedProvider), isFalse);

    await c.read(analyticsConsentProvider.future);
    expect(c.read(analyticsConsentProvider).value, AnalyticsConsent.unasked);
    expect(c.read(analyticsAllowedProvider), isFalse);
  });

  test('a declined answer is remembered, and is not "unasked"', () async {
    SharedPreferences.setMockInitialValues({'analytics_consent': 'declined'});
    final c = container();

    await c.read(analyticsConsentProvider.future);
    expect(c.read(analyticsConsentProvider).value, AnalyticsConsent.declined);
    expect(c.read(analyticsAllowedProvider), isFalse,
        reason: 'declining must not be re-asked into a yes');
  });

  test('a granted answer survives a restart', () async {
    SharedPreferences.setMockInitialValues({'analytics_consent': 'granted'});
    final c = container();

    await c.read(analyticsConsentProvider.future);
    expect(c.read(analyticsAllowedProvider), isTrue);
  });

  test('the route observer does nothing until consent is granted', () async {
    // It is a plain NavigatorObserver, not a FirebaseAnalyticsObserver: the
    // screen_view for /splash fired from here, before anything was asked.
    // Reaching FirebaseAnalytics.instance in a test would throw, so this also
    // proves the provider short-circuits before touching Firebase at all.
    final c = container();
    await c.read(analyticsConsentProvider.future);

    final observer = c.read(analyticsObserverProvider);
    expect(observer.runtimeType, NavigatorObserver);
  });

  test('collection is switched off before the first frame', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('setAnalyticsCollectionEnabled(false)'));
    expect(
      main.indexOf('setAnalyticsCollectionEnabled(false)') <
          main.indexOf('runApp('),
      isTrue,
      reason: 'switching it off after runApp is a race with the first screen',
    );
  });

  test('the choice is reachable again from the profile', () {
    // Apple requires withdrawal to be as easy to find as the original consent.
    expect(
      File('lib/presentation/screens/shared/profile_screen.dart')
          .readAsStringSync(),
      contains('AnalyticsConsentTile'),
    );
  });
}
