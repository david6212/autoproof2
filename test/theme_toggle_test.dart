// The switch has to represent a three-state setting with two positions. The
// case worth pinning is "follow the device": the switch must show what the
// device is actually doing, or a user on a dark phone sees an app that is
// clearly dark next to a switch that says it is off.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/providers/theme_provider.dart';

/// The rule the switch reads, lifted out so it can be checked directly.
bool switchIsOn(ThemeMode mode, {required bool deviceIsDark}) => switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => deviceIsDark,
    };

void main() {
  group('what the switch shows', () {
    test('follows the device while the setting is "system"', () {
      expect(switchIsOn(ThemeMode.system, deviceIsDark: true), isTrue);
      expect(switchIsOn(ThemeMode.system, deviceIsDark: false), isFalse);
    });

    test('an explicit choice wins over the device', () {
      expect(switchIsOn(ThemeMode.dark, deviceIsDark: false), isTrue);
      expect(switchIsOn(ThemeMode.light, deviceIsDark: true), isFalse);
    });
  });

  group('ThemeModeNotifier', () {
    test('starts on the device setting', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('flipping the switch records a deliberate choice', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await container.read(themeModeProvider.notifier).set(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('the reset link hands the decision back to the device', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      await container.read(themeModeProvider.notifier).set(ThemeMode.system);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });
}
