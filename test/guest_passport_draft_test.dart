import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/data/repositories/gov_api_repository.dart';
import 'package:bonnetcheck/presentation/providers/auth_provider.dart';
import 'package:bonnetcheck/presentation/providers/gov_api_provider.dart';
import 'package:bonnetcheck/presentation/providers/vehicle_draft_provider.dart';
import 'package:bonnetcheck/presentation/widgets/guest_garage_intro.dart';

/// The garage used to open on a login wall — a stranger was asked to commit
/// before they had seen anything of their own. Now they type their plate,
/// the registry answers with their car, and only then does the app ask for
/// an account, to keep what is already on screen.
///
/// These pin the reversal, and the one thing that makes it work at all: the
/// draft has to survive signing in, because signing in destroys the screen
/// that built it.
class _FakeGov extends GovApiRepository {
  _FakeGov(this.data);

  final GovData data;
  String? askedFor;

  @override
  Future<GovData> lookupPlate(String rawPlate) async {
    askedFor = rawPlate;
    return data;
  }
}

void main() {
  GovData govData() => GovData(
        plate: '67688002',
        make: 'ב.מ.וו',
        commercialName: '320i',
        model: '320i',
        year: 2021,
        color: 'שחור מטלי',
        fuelType: 'בנזין',
        ownershipType: 'פרטי',
        trim: '',
        lastTestDate: DateTime(2026, 3, 1),
        licenseExpiry: DateTime(2027, 3, 1),
        safetyRating: '',
        chassis: '',
        lastTestKm: 61756,
      );

  Widget host(_FakeGov gov) => ProviderScope(
        overrides: [
          govApiRepositoryProvider.overrideWithValue(gov),
          // A signed-out visitor. Null is a legitimate User? — no mock needed.
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: GuestGarageIntro()),
          ),
        ),
      );

  group('what a guest meets in the garage', () {
    testWidgets('asks for a plate, not for an account', (tester) async {
      await tester.pumpWidget(host(_FakeGov(govData())));
      await tester.pump();

      expect(find.text('מה רשום על הרכב שלכם?'), findsOneWidget);
      expect(find.text('הצג את הרכב שלי'), findsOneWidget);
      // The wall that used to be here. Its absence is the whole change: an
      // account is no longer the price of looking.
      expect(find.text('התחברות'), findsNothing);
    });

    testWidgets('promises the lookup costs nothing', (tester) async {
      // Reciprocity only works if the reader believes it before they act.
      await tester.pumpWidget(host(_FakeGov(govData())));
      await tester.pump();

      expect(find.textContaining('בלי הרשמה'), findsOneWidget);
    });
  });

  group('after the registry answers', () {
    testWidgets('shows the visitor their own car', (tester) async {
      final gov = _FakeGov(govData());
      await tester.pumpWidget(host(gov));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '67688002');
      await tester.tap(find.text('הצג את הרכב שלי'));
      await tester.pumpAndSettle();

      expect(gov.askedFor, '67688002');
      expect(find.text('זה הרכב שלכם'), findsOneWidget);
      expect(find.textContaining('ב.מ.וו'), findsOneWidget);
      // Attribution, not a claim of our own — the data is the ministry's.
      expect(find.textContaining('ממרשם הרכב'), findsOneWidget);
    });

    testWidgets('the ask names what is kept, not what is opened',
        (tester) async {
      await tester.pumpWidget(host(_FakeGov(govData())));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '67688002');
      await tester.tap(find.text('הצג את הרכב שלי'));
      await tester.pumpAndSettle();

      expect(find.text('שמרו את התיק הזה'), findsOneWidget);
      // And it stays honest about what the account is actually for: the data
      // they just read remains free without one.
      expect(find.textContaining('זמינים גם בלעדיו'), findsOneWidget);
    });

    testWidgets('holding the draft is what survives signing in',
        (tester) async {
      // The draft must be stored BEFORE navigating to login, because login
      // ends on context.go and disposes this screen with its controller.
      final gov = _FakeGov(govData());
      final container = ProviderContainer(overrides: [
        govApiRepositoryProvider.overrideWithValue(gov),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      ]);
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/garage',
        routes: [
          GoRoute(
            path: '/garage',
            builder: (_, __) => const Scaffold(body: GuestGarageIntro()),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('מסך התחברות')),
          ),
        ],
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (_, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '67688002');
      await tester.tap(find.text('הצג את הרכב שלי'));
      await tester.pumpAndSettle();

      expect(container.read(vehicleDraftProvider), isNull);

      await tester.enterText(find.byType(TextField).last, 'האוטו של אמא');
      await tester.tap(find.text('שמרו את התיק הזה'));
      await tester.pumpAndSettle();

      // Held first, navigated second — in that order, or the draft dies with
      // the screen that built it.
      expect(find.text('מסך התחברות'), findsOneWidget);

      final draft = container.read(vehicleDraftProvider);
      expect(draft, isNotNull);
      expect(draft!.gov.plate, '67688002');
      expect(draft.nickname, 'האוטו של אמא');
      // Pre-filled from the registry's last test reading, so the owner is not
      // sent out to the car to read the dash.
      expect(draft.currentKm, 61756);
    });
  });

  group('the draft itself', () {
    test('is not thrown away when there is nobody to claim it', () async {
      // A failed or abandoned sign-in must not cost the visitor the car they
      // just built. Returning null while keeping the draft lets the next
      // successful sign-in still claim it.
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      ]);
      addTearDown(container.dispose);

      container
          .read(vehicleDraftProvider.notifier)
          .hold(VehicleDraft(gov: govData(), nickname: 'זמני'));

      final id = await container.read(vehicleDraftProvider.notifier).claim();

      expect(id, isNull);
      expect(container.read(vehicleDraftProvider), isNotNull,
          reason: 'the car they built has to still be there');
    });

    test('clears on request', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(vehicleDraftProvider.notifier);
      notifier.hold(VehicleDraft(gov: govData()));
      expect(container.read(vehicleDraftProvider), isNotNull);

      notifier.clear();
      expect(container.read(vehicleDraftProvider), isNull);
    });
  });
}
