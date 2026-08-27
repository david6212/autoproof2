import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/fuel_station.dart';
import 'package:bonnetcheck/presentation/providers/gov_api_provider.dart';
import 'package:bonnetcheck/presentation/screens/buyer/fuel_stations_screen.dart';
import 'package:bonnetcheck/presentation/widgets/map_attribution.dart';

/// The two screens with a map on them, built the way a phone builds them.
///
/// **Both were completely dead on Android for days while the website was
/// fine.** `osmTileLayer` handed `NetworkTileProvider` a `const` headers map;
/// flutter_map writes its own `User-Agent` into that map at runtime, and
/// writing to a const map throws `UnsupportedError: Cannot modify unmodifiable
/// map`. It happens during `build`, so the whole screen is replaced — in
/// release, by a grey rectangle with no text.
///
/// It could never reproduce in a browser: a browser forbids setting
/// `User-Agent`, so flutter_map skips the write on web entirely. Every check
/// that ran against the live site passed while the APK was broken.
///
/// These tests run on the Dart VM, which has the same semantics as Android and
/// not the browser's. That is the whole reason they catch it.
void main() {
  const stations = [
    FuelStation(
      id: '1',
      company: 'פז',
      name: 'תחנה א',
      address: 'הרצל 1',
      city: 'תל אביב',
      lat: 32.07,
      lng: 34.78,
    ),
    FuelStation(
      id: '2',
      company: 'סונול',
      name: 'תחנה ב',
      address: 'הנמל 2',
      city: 'חיפה',
      lat: 32.79,
      lng: 34.99,
    ),
  ];

  Widget host(Widget child) => ProviderScope(
        overrides: [
          fuelStationsProvider.overrideWith((ref) async => stations),
          dieselReferenceProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      );

  testWidgets('the fuel screen builds without throwing', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const FuelStationsScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull,
        reason: 'a throw here is a grey rectangle on a real phone');
    // And it really did reach the data branch, rather than passing by
    // staying on a loading state that throws nothing.
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('it fits a narrow phone without clipping', (tester) async {
    // 320dp is the narrowest Android phone still in use. A Row that does not
    // fit does not shrink — it clips, and the clipped half is a control the
    // reader can no longer reach. The sort chips overflowed by 37px at 360dp.
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const FuelStationsScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // Both sort controls are still reachable, on whatever line they land.
    expect(find.text('הקרובות אליי'), findsOneWidget);
    expect(find.text('המחיר שדווח'), findsOneWidget);
  });

  testWidgets('the tile layer hands over headers a library may write to',
      (tester) async {
    // The precise failure, isolated: flutter_map does not copy this map, it
    // writes into it.
    final layer = osmTileLayer();
    expect(
      () => layer.tileProvider.headers['User-Agent'] = 'anything',
      returnsNormally,
      reason: 'a const map here kills every screen that shows a map',
    );
  });

  test('the User-Agent names the version that is actually running', () {
    // It read `BonnetCheck/0.5.0` for months, which identifies a build nobody
    // has. OSM's tile policy asks for a contact and a real identifier; a
    // frozen version number quietly makes that a lie.
    final ua = osmTileLayer().tileProvider.headers['User-Agent'] ?? '';
    expect(ua, contains('bonnetcheck.web.app'));
    expect(ua.contains('0.5.0'), isFalse);
  });
}
