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
import '../presentation/screens/verify/verify_role_screen.dart';
import '../presentation/screens/verify/verify_phone_screen.dart';
import '../presentation/screens/verify/verify_plate_screen.dart';
import '../presentation/screens/verify/verify_success_screen.dart';
// Buyer
import '../presentation/screens/buyer/home_screen.dart';
import '../presentation/screens/buyer/car_detail_screen.dart';
import '../presentation/screens/buyer/vehicle_history_screen.dart';
import '../presentation/screens/buyer/fuel_stations_screen.dart';
import '../presentation/screens/buyer/inspectors_screen.dart';
import '../presentation/screens/buyer/saved_screen.dart';
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
  return GoRouter(
    initialLocation: '/splash',
    // Auto-logs a screen_view analytics event for every pushed route.
    observers: [ref.watch(analyticsObserverProvider)],
    redirect: (context, state) {
      // RULE 1 — Seller gate: only verified users may create a listing, and
      // only with a phone number on file. Google/Apple sign-in carries no
      // number, so without this a throwaway account could publish anonymously.
      if (state.matchedLocation == '/seller/create') {
        final user = ref.read(currentUserModelProvider).valueOrNull;
        // Only block when we positively know the user is NOT eligible.
        if (user != null && !user.verified) {
          return '/verify/role';
        }
        if (user != null && !user.hasPhone) {
          return '/verify/phone';
        }
      }
      return null;
    },
    routes: [
      // Auth
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(
          path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),

      // Verify
      GoRoute(
          path: '/verify/role', builder: (c, s) => const VerifyRoleScreen()),
      GoRoute(
          path: '/verify/plate', builder: (c, s) => const VerifyPlateScreen()),
      GoRoute(
          path: '/verify/phone', builder: (c, s) => const VerifyPhoneScreen()),
      GoRoute(
          path: '/verify/success',
          builder: (c, s) => const VerifySuccessScreen()),

      // Buyer shell (with bottom TabBar)
      ShellRoute(
        builder: (c, s, child) => BuyerShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
          GoRoute(path: '/fuel', builder: (c, s) => const FuelStationsScreen()),
          GoRoute(path: '/chats', builder: (c, s) => const ChatListScreen()),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
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
