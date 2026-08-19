import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bonnetcheck/presentation/providers/alert_prefs_provider.dart';

/// Which alerts the app may raise, and the reader's power to refuse each one.
///
/// The list is as much a product decision as a technical one: four kinds, each
/// of which costs the reader something real if we stay quiet. The tests guard
/// the boundary in both directions — nothing engagement-shaped creeps in, and
/// every switch actually reaches the surface it claims to control.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the list itself', () {
    test('holds only alerts the reader would lose something by missing', () {
      // If this ever grows, the new entry has to survive the same question:
      // absent this alert, is the reader worse off in fact — not in engagement?
      expect(AlertKind.values, hasLength(4));
      expect(
        AlertKind.values.toSet(),
        {
          AlertKind.reminders,
          AlertKind.recalls,
          AlertKind.priceDrops,
          AlertKind.chatReplies,
        },
      );
    });

    test('every switch says what turning it off costs', () {
      // A toggle whose consequence is hidden is not a choice.
      for (final kind in AlertKind.values) {
        expect(kind.label.trim(), isNotEmpty, reason: kind.name);
        expect(kind.cost.trim(), isNotEmpty, reason: kind.name);
      }
    });

    test('no label or cost line applies pressure', () {
      // Same rule as ethics_test, applied to the copy that argues for keeping
      // alerts on — the most tempting place in the app to push.
      const banned = ['מיהרו', 'אל תפספסו', 'הזדמנות', 'נותרו רק', 'חובה'];
      for (final kind in AlertKind.values) {
        final copy = '${kind.label} ${kind.cost}';
        for (final word in banned) {
          expect(copy.contains(word), isFalse,
              reason: '${kind.name}: "$word"');
        }
        expect(copy.contains('!'), isFalse, reason: kind.name);
      }
    });
  });

  group('defaults and memory', () {
    test('everything starts on', () async {
      // Someone who has expressed no preference is better served by hearing
      // that their test expires than by silence.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(alertPrefsProvider), AlertKind.values.toSet());
    });

    test('switching one off leaves the others alone', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(alertPrefsProvider.notifier)
          .set(AlertKind.priceDrops, false);

      final on = container.read(alertPrefsProvider);
      expect(on.contains(AlertKind.priceDrops), isFalse);
      expect(on.contains(AlertKind.reminders), isTrue);
      expect(on.contains(AlertKind.recalls), isTrue);
      expect(on.contains(AlertKind.chatReplies), isTrue);
    });

    test('a choice is written down and survives a restart', () async {
      final first = ProviderContainer();
      await first
          .read(alertPrefsProvider.notifier)
          .set(AlertKind.recalls, false);
      first.dispose();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('alert.recalls'), isFalse);

      // A fresh container stands in for the next launch.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(alertPrefsProvider);
      await Future<void>.delayed(Duration.zero);

      expect(second.read(alertPrefsProvider).contains(AlertKind.recalls),
          isFalse);
    });

    test('turning one back on is remembered too', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(alertPrefsProvider.notifier);

      await notifier.set(AlertKind.reminders, false);
      await notifier.set(AlertKind.reminders, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('alert.reminders'), isTrue);
      expect(container.read(alertPrefsProvider), AlertKind.values.toSet());
    });
  });

  group('the gate the screens read', () {
    test('reports each kind independently', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(alertPrefsProvider.notifier)
          .set(AlertKind.reminders, false);

      expect(container.read(alertEnabledProvider(AlertKind.reminders)), isFalse);
      expect(container.read(alertEnabledProvider(AlertKind.recalls)), isTrue);
    });
  });
}
