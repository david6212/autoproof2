import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/providers/create_listing_provider.dart';
import 'package:bonnetcheck/presentation/widgets/publish_fab.dart';

/// How somebody gets into the publish flow, and what stops them at the end.
///
/// Publishing was reachable from the profile menu and from the seller area —
/// both of which you have to already know exist. A visitor browsing listings
/// who realised they could sell theirs too had no way in from the screen they
/// were on, and a guest had no way in at all.
void main() {
  testWidgets('the way in is labelled, not just an icon', (tester) async {
    // Extended rather than a bare circle: a car glyph alone would be read as
    // "my cars" on a screen full of cars, which is the one place the button
    // has to be unambiguous.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(floatingActionButton: PublishFab()),
    ));
    await tester.pump();

    expect(find.text('פרסום רכב'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car), findsOneWidget);
  });

  test('a listing cannot be published without an account', () async {
    // It used to fall back to a literal 'test-user' uid. Harmless while the
    // flow was behind a login wall; the moment guests were let in, it would
    // have published real cars under an account nobody can sign in to — so
    // nobody could edit or remove them either.
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await c.read(createListingControllerProvider.notifier).publish();

    final state = c.read(createListingControllerProvider);
    expect(state.publishedId, isNull);
    expect(state.error, isNotNull);

    final source = File('lib/presentation/providers/create_listing_provider.dart')
        .readAsStringSync();
    // The literal is still named in the comment explaining why it went; what
    // must not come back is the fallback itself.
    expect(source.contains("?? 'test-user'"), isFalse);
  });

  test('the seller area no longer floats a fuel button over the sale', () {
    // A fuel-station shortcut hovering over "פרסם את הרכב שלך" answers a
    // question nobody is asking mid-sale, and a floating button is the
    // loudest thing on a screen — it should be the action that screen is for.
    expect(File('lib/presentation/widgets/fuel_fab.dart').existsSync(), isFalse);

    final shell =
        File('lib/presentation/widgets/seller_shell.dart').readAsStringSync();
    expect(shell.contains('FuelFab'), isFalse);
    expect(shell.contains('floatingActionButton'), isFalse);

    // Fuel keeps its tab on the buyer side — the route is not orphaned.
    final buyer =
        File('lib/presentation/widgets/buyer_shell.dart').readAsStringSync();
    expect(buyer, contains("'/fuel'"));
  });
}
