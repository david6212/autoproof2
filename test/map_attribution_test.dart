import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/presentation/widgets/map_attribution.dart';

/// The tiles are borrowed, and the credit is the rent.
///
/// Both maps ran with no OpenStreetMap attribution at all until 2026-08-22.
/// That is an ODbL breach rather than an oversight, and the OSMF's stated
/// remedy is to block the application at the tile server without notice —
/// which would empty the fuel map and the inspection-centre map at once, with
/// no fallback provider in the code.
void main() {
  testWidgets('the credit is visible without touching the map', (tester) async {
    // The guideline is explicit that attribution "should not require
    // individuals to interact with the map to see" it — which is why this is
    // not flutter_map's RichAttributionWidget, whose default hides the credit
    // behind a button.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Stack(children: [MapAttribution()])),
    ));
    await tester.pump();

    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  test('every map in the app draws its tiles through the credited layer', () {
    // A screen that builds its own TileLayer would be a map with no credit,
    // and nobody would notice until the tiles stopped arriving.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('map_attribution.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // `osmTileLayer(` contains `TileLayer(` — the helper is the fix, not
        // an offender.
        if (line.contains('osmTileLayer(')) continue;
        if (line.contains('TileLayer(') ||
            line.contains('tile.openstreetmap.org')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'use osmTileLayer() from map_attribution.dart');
  });

  test('a map screen shows the credit', () {
    for (final path in const [
      'lib/presentation/screens/buyer/fuel_stations_screen.dart',
      'lib/presentation/screens/buyer/inspectors_screen.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('MapAttribution()'),
          reason: '$path draws tiles and must credit them');
    }
  });

  test('the tile request names this app and a way to reach us', () {
    // The policy asks for a User-Agent that identifies the application; the
    // default named a package id that no longer matches the product name and
    // gave OSMF nobody to contact before blocking it.
    final src =
        File('lib/presentation/widgets/map_attribution.dart').readAsStringSync();
    expect(src, contains('BonnetCheck/'));
    expect(src, contains('support@bonnetcheck.com'));
  });
}
