import 'package:flutter_test/flutter_test.dart';

import 'package:otov/presentation/widgets/fuel_fab.dart';

/// The fuel shortcut floats over every tab, which means it also floats over
/// whatever each tab already put in that corner. `/discover` is the swipe deck
/// and its skip/save buttons sit exactly there — the one place the button has
/// to stand down.
void main() {
  test('shows on the ordinary tabs', () {
    for (final path in [
      '/home',
      '/saved',
      '/chats',
      '/profile',
      '/seller',
      '/seller/listing',
      '/seller/create',
    ]) {
      expect(FuelFab.visibleAt(path), isTrue, reason: path);
    }
  });

  test('stands down on the swipe deck, including sub-routes', () {
    expect(FuelFab.visibleAt('/discover'), isFalse);
    expect(FuelFab.visibleAt('/discover/anything'), isFalse);
  });

  test('a path that merely contains "discover" is not treated as the deck', () {
    // startsWith, not contains — otherwise a future '/car/discovery-tips'
    // would silently lose the button.
    expect(FuelFab.visibleAt('/car/discover-tips'), isTrue);
  });
}
