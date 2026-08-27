import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/app_colors.dart';

/// The two generated map styles.
///
/// They are build artefacts of `tool/gen_map_style.py`, checked in because the
/// app bundles them — which means they can go stale against the palette
/// without anything failing to compile. These tests are what notices.
///
/// The map replaced raster tiles from `tile.openstreetmap.org`, which were
/// somebody else's colours and, more to the point, a volunteer-funded server
/// whose usage policy is written for light use rather than for an app being
/// handed out to people.
void main() {
  Map<String, dynamic> read(String name) => jsonDecode(
        File('assets/map/bonnetcheck-$name.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  String hex(int argb) =>
      '#${argb.toRadixString(16).substring(2).toUpperCase()}';

  List<Map<String, dynamic>> layers(Map<String, dynamic> style) =>
      (style['layers'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> layer(Map<String, dynamic> style, String id) =>
      layers(style).firstWhere((l) => l['id'] == id);

  group('both styles exist and are loadable', () {
    for (final name in const ['light', 'dark']) {
      test('$name parses and has layers', () {
        final style = read(name);
        expect(style['version'], 8);
        expect(layers(style), isNotEmpty);
        expect(style['sources'], isNotEmpty);
        // Glyphs are what draws the Hebrew place names. A style without them
        // renders a map with no labels at all.
        expect(style['glyphs'], isNotNull);
      });
    }
  });

  test('the light ground is the app\'s own page colour', () {
    // The map should look like part of the app, not like a window cut into it.
    final bg = layer(read('light'), 'background')['paint']['background-color'];
    expect(bg, hex(AppColors.background.toARGB32()));
  });

  test('the two themes really are different', () {
    // Both files are the same byte length, because every colour in them is
    // exactly seven characters. Length is not evidence of anything.
    expect(read('light')['layers'], isNot(equals(read('dark')['layers'])));
  });

  test('the sea is visible against the land in both themes', () {
    // The dark theme shipped once with water at #141C1F on a #101312 ground
    // and the Mediterranean was invisible. On a map of Israel the coastline is
    // how a person orients themselves before reading a single label.
    for (final name in const ['light', 'dark']) {
      final style = read(name);
      final ground =
          layer(style, 'background')['paint']['background-color'] as String;
      final water = layer(style, 'water')['paint']['fill-color'] as String;

      int lum(String h) {
        final v = int.parse(h.substring(1), radix: 16);
        return ((v >> 16 & 0xFF) * 299 + (v >> 8 & 0xFF) * 587 + (v & 0xFF) * 114) ~/
            1000;
      }

      expect((lum(water) - lum(ground)).abs(), greaterThanOrEqualTo(12),
          reason: '$name: water and land are too close to tell apart');
    }
  });

  test('labels ask for Hebrew first', () {
    // Positron concatenates the Latin and non-Latin names, so every town would
    // read "Tel Aviv-Yafo תל אביב-יפו" on one line. In an app that is Hebrew
    // throughout, the Latin half is noise.
    for (final name in const ['light', 'dark']) {
      final city = layer(read(name), 'label_city');
      final field = jsonEncode(city['layout']['text-field']);
      expect(field, contains('name:he'));
      expect(field, isNot(contains('name:nonlatin')),
          reason: '$name still carries the two-language label');
    }
  });

  test('nothing points at the old raster tile server', () {
    // The fallback in map_basemap.dart still may; a *style* must not.
    for (final name in const ['light', 'dark']) {
      final raw = File('assets/map/bonnetcheck-$name.json').readAsStringSync();
      expect(raw.contains('tile.openstreetmap.org'), isFalse);
    }
  });

  test('the generator is checked in beside its output', () {
    // Without it the styles are 20KB of unexplained JSON that nobody can
    // safely change.
    expect(File('tool/gen_map_style.py').existsSync(), isTrue);
  });
}
