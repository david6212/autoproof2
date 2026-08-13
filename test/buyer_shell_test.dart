import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/widgets/buyer_shell.dart';

/// The bottom bar is the app's whole navigation model, and every one of its
/// destinations has to be a route that exists. A tab pointing at a deleted
/// screen fails at runtime with a blank page, not at compile time — which is
/// exactly how the swipe deck's removal could have gone wrong.
void main() {
  test('the five buyer tabs are the ones we expect, in order', () {
    // RTL, so the first entry is the rightmost on screen.
    expect(BuyerShell.tabPaths,
        ['/home', '/saved', '/fuel', '/chats', '/profile']);
  });

  test('the swipe deck is really gone', () {
    // It showed the same cars as the home list through the same filter, so it
    // was a second route to one place rather than a second thing to do.
    expect(BuyerShell.tabPaths, isNot(contains('/discover')));
  });

  test('every tab path is distinct', () {
    // Two tabs on one path makes the selected-index lookup pick the first and
    // the other can never light up.
    expect(BuyerShell.tabPaths.toSet(), hasLength(BuyerShell.tabPaths.length));
  });

  test('the fuel tab sits in the middle slot', () {
    expect(BuyerShell.tabPaths.indexOf('/fuel'), 2);
  });
}
