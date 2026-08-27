import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/presentation/screens/auth/login_screen.dart';
import 'package:bonnetcheck/presentation/screens/auth/onboarding_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/add_vehicle_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/claim_vehicle_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/compare_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/garage_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/notifications_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/past_vehicles_screen.dart';
import 'package:bonnetcheck/presentation/screens/buyer/saved_screen.dart';
import 'package:bonnetcheck/presentation/screens/places/add_place_screen.dart';
import 'package:bonnetcheck/presentation/screens/seller/listing_removed_screen.dart';
import 'package:bonnetcheck/presentation/screens/shared/about_screen.dart';
import 'package:bonnetcheck/presentation/screens/shared/chat_list_screen.dart';
import 'package:bonnetcheck/presentation/screens/shared/legal_screen.dart';
import 'package:bonnetcheck/presentation/screens/shared/profile_screen.dart';

/// Every screen, built the way a phone builds it.
///
/// **Written after two map screens were dead on Android for days** while every
/// check against the live website passed. `osmTileLayer` handed flutter_map a
/// `const` headers map and flutter_map wrote into it; a browser never
/// performs that write, so the browser never saw the crash. In release the
/// result is a grey rectangle with no text, which is indistinguishable from
/// "the screen is empty" to the person reporting it.
///
/// These run on the Dart VM. Its semantics are Android's, not a browser's —
/// which is the entire reason a test here can catch what a headless Chrome
/// pass cannot. The bar is deliberately low and worth having: **does this
/// screen build at all, on a phone-sized viewport, without throwing.**
void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      );

  /// The screens reachable without an account or a route argument. Anything
  /// needing a real id or a signed-in user is covered by its own test.
  final screens = <String, Widget Function()>{
    'onboarding': () => const OnboardingScreen(),
    'login': () => const LoginScreen(),
    'garage': () => const GarageScreen(),
    'saved': () => const SavedScreen(),
    'compare': () => const CompareScreen(),
    'profile': () => const ProfileScreen(),
    'about': () => const AboutScreen(),
    'legal': () => const LegalScreen(),
    'chats': () => const ChatListScreen(),
    'notifications': () => const NotificationsScreen(),
    'past vehicles': () => const PastVehiclesScreen(),
    'add vehicle': () => const AddVehicleScreen(),
    'claim vehicle': () => const ClaimVehicleScreen(),
    'add place': () => const AddPlaceScreen(),
    'listing removed': () => const ListingRemovedScreen(),
  };

  /// Android's accessibility text sizes go well past 1.0, and a reader who
  /// needs them is exactly the reader least able to work around a clipped
  /// control. 1.5 is inside what the OS offers, not an extreme.
  Widget scaled(Widget child, double scale) => MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      );

  for (final entry in screens.entries) {
    testWidgets('${entry.key} builds on a phone', (tester) async {
      // A real mid-range Android phone, not the 800x600 default a widget test
      // would otherwise use — layout faults hide at the wrong size.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(entry.value()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: 'on a phone this is a grey rectangle, not an error message');
    });

    testWidgets('${entry.key} survives large system text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(scaled(host(entry.value()), 1.5));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull,
          reason: 'the onboarding art clipped itself at 1.0 already, and '
              'anything built from text grows from here');
    });
  }
}
