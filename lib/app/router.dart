import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/analytics_provider.dart';

// Auth
import '../presentation/screens/auth/splash_screen.dart';
import '../presentation/screens/auth/onboarding_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
// Verify
import '../presentation/screens/verify/verify_phone_screen.dart';
// Buyer
import '../presentation/screens/buyer/home_screen.dart';
import '../presentation/screens/buyer/car_detail_screen.dart';
import '../presentation/screens/buyer/vehicle_history_screen.dart';
import '../presentation/screens/buyer/fuel_stations_screen.dart';
import '../presentation/screens/buyer/inspectors_screen.dart';
import '../presentation/screens/buyer/saved_screen.dart';
import '../presentation/screens/buyer/garage_screen.dart';
import '../presentation/screens/buyer/add_vehicle_screen.dart';
import '../presentation/screens/buyer/vehicle_detail_screen.dart';
import '../presentation/screens/buyer/publish_from_vehicle_screen.dart';
import '../presentation/screens/buyer/sell_vehicle_screen.dart';
import '../presentation/screens/buyer/claim_vehicle_screen.dart';
import '../presentation/screens/buyer/past_vehicles_screen.dart';
import '../presentation/screens/buyer/compare_screen.dart';
import '../presentation/screens/buyer/notifications_screen.dart';
// Seller
import '../presentation/screens/seller/seller_home_screen.dart';
import '../presentation/screens/seller/create_listing_screen.dart';
import '../presentation/screens/seller/my_listing_screen.dart';
import '../presentation/screens/seller/listing_removed_screen.dart';
// Shared
import '../presentation/screens/shared/chat_list_screen.dart';
import '../presentation/screens/shared/chat_screen.dart';
import '../presentation/screens/shared/profile_screen.dart';
import '../presentation/screens/shared/about_screen.dart';
import '../presentation/screens/shared/legal_screen.dart';
// Shells
import '../presentation/widgets/buyer_shell.dart';
import '../presentation/widgets/seller_shell.dart';

/// Routes that cannot work at all without an account.
///
/// A passport is private by security rule, so a signed-out visitor who follows
/// a link to one does not get a login prompt — they get a Firestore permission
/// error dressed as "we couldn't load this", with a retry button that can
/// never succeed. Better to say what is actually needed.
///
/// `/garage` itself is deliberately NOT here: it is a bottom tab, and a tab
/// that bounces you to a login screen is hostile. That screen lets a guest
/// look their own car up in the registry and offers to keep the result,
/// which is the invitation. It is the actions underneath that need the
/// account.
bool needsAccount(String location) {
  const gated = [
    '/garage/add',
    '/garage/claim',
    '/vehicle/',
    '/profile/past-vehicles',
  ];
  return gated.any(location.startsWith);
}

/// The account decision for one location, separated from the router so that it
/// can be tested at all.
///
/// It could not be before. The router exposed only [needsAccount] — the pure
/// half — and the tests dutifully covered that, while the half that actually
/// ran in front of users went unexercised. The suite stayed green for the
/// entire time the guard was doing nothing on a cold start.
///
/// [auth] arrives as the raw async value on purpose. "Still loading" is a
/// third answer, distinct from signed-out, and collapsing the two is its own
/// bug: a signed-in user opening the app on a link would be thrown to the
/// login screen during the first frames, every time.
String? accountRedirect(String location, AsyncValue<User?> auth) {
  if (!needsAccount(location)) return null;

  // Undecided. Let the screen build; [AuthRefresh] brings us back here the
  // moment the answer arrives.
  if (!auth.hasValue) return null;

  return auth.value == null ? '/login' : null;
}

/// Tells go_router to re-run its redirect once the auth answer arrives.
///
/// Without this the guard is decoration on a cold start. `redirect` runs once
/// per navigation, and a link opened from outside the app arrives while
/// `authStateProvider` is still loading — so [accountRedirect] rightly
/// declines to decide, and then nothing ever asks it again. The visitor is
/// left on a passport that cannot load, under a retry button that cannot
/// succeed.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<User?>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<User?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Back navigation that survives being opened from a link.
///
/// A shared listing URL opens straight onto `/car/:id`, so there is nothing
/// on the stack to pop and a plain `context.pop()` is a dead button. Fall
/// back to the listings instead.
void popOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    // Auto-logs a screen_view analytics event for every pushed route.
    // A do-nothing observer until analytics consent is granted — see
    // analytics_observer_provider. GoRouter accepts any NavigatorObserver.
    observers: [ref.watch(analyticsObserverProvider)],
    refreshListenable: refresh,
    redirect: (context, state) {
      // RULE 1 — the seller gate moved INTO the flow.
      //
      // It used to bounce anyone without a verified account away from
      // `/seller/create` before they saw anything, which is why the journey
      // was eight screens: three of them existed only to satisfy this
      // redirect. Verification now happens in step 1 (the registry check) and
      // step 4 (the phone), where the seller can see what they are for.
      // `CreateListingController.publish` refuses without both — the same
      // client-side strength the redirect had.
      // RULE 2 — the passport needs an account, because it is private by
      // security rule rather than by convention.
      return accountRedirect(
        state.matchedLocation,
        ref.read(authStateProvider),
      );
    },
    routes: [
      // Auth
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),

      // Verify. Only the phone step is still a screen of its own; the role
      // question and the ownership check live inside the publish flow now.
      GoRoute(
          path: '/verify/phone', builder: (c, s) => const VerifyPhoneScreen()),

      // Buyer shell (with bottom TabBar)
      ShellRoute(
        builder: (c, s, child) => BuyerShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/garage', builder: (c, s) => const GarageScreen()),
          GoRoute(path: '/fuel', builder: (c, s) => const FuelStationsScreen()),
          GoRoute(path: '/chats', builder: (c, s) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),

      // Saved gave up its tab to the garage and is now reached from two
      // places — the Home header and the profile menu. So it is pushed rather
      // than living in the shell: a back arrow returns to whichever one you
      // came from, where a fixed highlighted tab would be wrong half the time.
      GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),

      // Passport screens (no TabBar — pushed, with a back arrow)
      GoRoute(
        path: '/garage/add',
        builder: (c, s) => const AddVehicleScreen(),
      ),
      GoRoute(
        path: '/vehicle/:id',
        builder: (c, s) =>
            VehicleDetailScreen(vehicleId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicle/:id/publish',
        builder: (c, s) =>
            PublishFromVehicleScreen(vehicleId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicle/:id/sell',
        builder: (c, s) =>
            SellVehicleScreen(vehicleId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/garage/claim',
        builder: (c, s) => const ClaimVehicleScreen(),
      ),
      GoRoute(
        path: '/profile/past-vehicles',
        builder: (c, s) => const PastVehiclesScreen(),
      ),

      // Car screens (no TabBar)
      GoRoute(
        path: '/car/:id',
        builder: (c, s) => CarDetailScreen(carId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/car/:id/history',
        builder: (c, s) =>
            VehicleHistoryScreen(carId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (c, s) => ChatScreen(chatId: s.pathParameters['chatId']!),
      ),
      GoRoute(
        path: '/inspectors/:carId',
        builder: (c, s) =>
            InspectorsScreen(carId: s.pathParameters['carId']!),
      ),
      GoRoute(
          path: '/notifications',
          builder: (c, s) => const NotificationsScreen()),
      // Outside the tab shell: the comparison is a full-width table and the
      // nav bar would eat the room it needs.
      GoRoute(path: '/compare', builder: (c, s) => const CompareScreen()),

      // Seller shell
      ShellRoute(
        builder: (c, s, child) => SellerShell(child: child),
        routes: [
          GoRoute(
              path: '/seller', builder: (c, s) => const SellerHomeScreen()),
          GoRoute(
              path: '/seller/listing',
              builder: (c, s) => const MyListingScreen()),
          GoRoute(
              path: '/seller/create',
              builder: (c, s) => const CreateListingScreen()),
          GoRoute(
              path: '/seller/removed',
              builder: (c, s) => const ListingRemovedScreen()),
        ],
      ),

      // Shared
      GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
      GoRoute(path: '/legal', builder: (c, s) => const LegalScreen()),
      GoRoute(
        path: '/legal/:docId',
        builder: (c, s) => LegalDocScreen(docId: s.pathParameters['docId']!),
      ),
    ],
  );
});
