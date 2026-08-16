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
