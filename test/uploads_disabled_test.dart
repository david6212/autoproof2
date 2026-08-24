import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/constants/app_config.dart';
import 'package:bonnetcheck/presentation/screens/buyer/add_service_screen.dart';

/// Firebase Storage has never been provisioned on this project, so every
/// upload fails at the network call. The app says so instead of finding out.
///
/// A button that always fails is worse than a button that is not there: the
/// person blames themselves, tries again, and stops trusting the parts that
/// do work. These pin that the affordance tracks the flag, in both directions,
/// so that turning Storage on is genuinely a one-line change.
void main() {
  // The form is a ListView, which builds only what fits on screen. A phone
  // viewport leaves the attachment row and the save button unbuilt, so the
  // test would pass for the wrong reason.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.physicalSize = const Size(1000, 3000);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: child,
          ),
        ),
      );

  testWidgets('no receipt picker is offered while uploads cannot work',
      (tester) async {
    await tester.pumpWidget(host(const AddServiceScreen(vehicleId: 'v1')));
    await tester.pump();

    if (AppConfig.storageEnabled) {
      expect(find.text('צרף קבלה'), findsOneWidget);
      expect(find.text(AppConfig.uploadsUnavailable), findsNothing);
    } else {
      expect(find.text('צרף קבלה'), findsNothing);
      expect(find.text(AppConfig.uploadsUnavailable), findsOneWidget);
    }
  });

  testWidgets('the rest of the record can still be written', (tester) async {
    // The point of hiding only the attachment: a service record without a
    // receipt is still evidence, and losing the whole feature over a missing
    // bucket would be the wrong trade.
    await tester.pumpWidget(host(const AddServiceScreen(vehicleId: 'v1')));
    await tester.pump();

    expect(find.text('מה נעשה'), findsOneWidget);
    expect(find.text('קילומטראז\''), findsOneWidget);
    expect(find.text('שמור רשומה'), findsOneWidget);
  });

  group('the affordances that lead nowhere are gone, not just labelled', () {
    // These read the source. The screens they describe need Firestore, a
    // TabController and a route to build, and the point being pinned is
    // structural: whether the control exists at all.

    test('the passport has no documents tab while there is no bucket', () {
      // It was a tab whose entire content was a sentence explaining that the
      // feature does not work. No document has ever been uploaded, because
      // none ever could be, so nothing is hidden by removing it.
      final src = File(
        'lib/presentation/screens/buyer/vehicle_detail_screen.dart',
      ).readAsStringSync();

      expect(src, contains('length: uploads ? 4 : 3'));
      expect(src, contains("if (uploads) Tab(text: 'מסמכים')"));
      expect(src, contains('if (uploads) _DocumentsTab(vehicle: vehicle)'));
    });

    test('publishing offers no photo picker, and does not demand a photo', () {
      // The two halves have to move together. The tile was the only way to
      // fill `photos`, and "המשך" was gated on `photos.isNotEmpty` — so
      // removing the tile without moving the gate would dead-end the app's
      // main action at step 3 of 4.
      final src = File(
        'lib/presentation/screens/seller/create_listing_screen.dart',
      ).readAsStringSync();

      // The picker only exists inside the flag's branch.
      final tile = src.indexOf('_AddTile(onTap: () => _pick(ref))');
      expect(tile, greaterThan(-1));
      expect(src.lastIndexOf('if (AppConfig.storageEnabled)', tile),
          greaterThan(-1),
          reason: 'the grid holding the add tile is behind the flag');
      expect(src, contains('!AppConfig.storageEnabled || photos.isNotEmpty'));
    });

    test('the seller is not told to upload photos', () {
      // Advice to do something the app cannot do sends the seller looking for
      // a button that is not there.
      final src = File(
        'lib/presentation/screens/seller/seller_home_screen.dart',
      ).readAsStringSync();

      final tip = src.indexOf('העלה לפחות 6 תמונות');
      expect(tip, greaterThan(-1));
      expect(src.substring(0, tip), contains('if (AppConfig.storageEnabled)'));
    });
  });

  test('the message says what is unavailable without blaming the user', () {
    const msg = AppConfig.uploadsUnavailable;
    expect(msg, contains('אינו זמין'));
    // No "error", no "failed", no "try again" — nothing the person did wrong,
    // and nothing they can fix by retrying.
    expect(msg.contains('שגיאה'), isFalse);
    expect(msg.contains('נכשל'), isFalse);
    expect(msg.contains('נסו שוב'), isFalse);
  });
}
