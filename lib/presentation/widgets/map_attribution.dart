import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';

/// The map tiles come from OpenStreetMap, and this says so.
///
/// It is not decoration and not politeness. The tiles are served under the
/// ODbL, and attribution is the condition of using them: the OSMF Attribution
/// Guideline requires the credit to be visible to anyone who sees the map,
/// **without interacting with it**, and the Tile Usage Policy says access "may
/// be blocked without prior notice" when it is missing. Both of this app's
/// maps ran without any credit at all until 2026-08-22.
///
/// That "without interacting" clause is why this is a plain always-visible
/// label rather than flutter_map's `RichAttributionWidget`, whose default
/// behaviour is to hide the credit behind an ⓘ button the reader has to press.
///
/// The word "OpenStreetMap" links to the copyright page, which is how the
/// guideline says to make the licence discoverable.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  static final _copyright = Uri.parse('https://www.openstreetmap.org/copyright');

  @override
  Widget build(BuildContext context) {
    return Align(
      // Top, not the conventional bottom corner. Both map screens keep a
      // draggable sheet over the lower half, so a bottom-aligned credit is
      // drawn underneath it and is never seen — which fails the part of the
      // guideline that matters: visible without interacting with the map.
      // Verified on the live site, not assumed.
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        // Clear of a glass app bar the map runs under: the credit has to be
        // visible, not behind the title.
        padding: EdgeInsets.fromLTRB(
            6, 6 + MediaQuery.paddingOf(context).top, 6, 6),
        child: GestureDetector(
          onTap: () => launchUrl(_copyright, mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              // Its own scrim rather than a theme surface: this sits on
              // photographic map tiles, which are neither light nor dark.
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              // Three parties, and all three are required.
              //
              // OSMF asks for the word **contributors** specifically — "© OpenStreetMap
              // contributors" — and the app shipped that correctly until the vector
              // basemap landed in 0.9.0, when the word was dropped. This was a
              // regression, not an omission: the store screenshot taken on 25/08 shows
              // the compliant string.
              //
              // OpenFreeMap serves the tiles and asks to be credited alongside
              // **OpenMapTiles**, whose schema the style is built on, and OpenMapTiles
              // was never named at all. Commercial use and unlimited views are
              // expressly granted, so attribution is the whole of the bargain.
              '© OpenStreetMap contributors · OpenFreeMap © OpenMapTiles',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF1A202C)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tile source, with a User-Agent that names this application.
///
/// The policy asks for "a clear, unique User-Agent string that names your app
/// and optionally includes a contact URL or email" — flutter_map's default
/// names the package id (`il.autoproof.autoproof`), which identifies a product
/// that no longer carries that name and gives OSMF nobody to contact before
/// blocking it.
///
/// The header cannot be set from a browser, so on web this falls back to
/// flutter_map's own provider and the contact address published on the site
/// is the only identification available.
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'il.autoproof.autoproof',
      tileProvider: NetworkTileProvider(
        // NOT const. flutter_map writes its own `User-Agent` into this very
        // map at runtime, and a const map is unmodifiable — the write throws
        // `UnsupportedError: Cannot modify unmodifiable map`, which happens
        // during build and takes the whole screen with it.
        //
        // It never showed up in a browser because a browser forbids setting
        // User-Agent at all, so flutter_map skips the write on web entirely.
        // Both maps in this app were dead on Android and fine on the site.
        headers: {
          'User-Agent':
              'BonnetCheck/${AppConfig.appVersion} (+https://bonnetcheck.web.app; support@bonnetcheck.com)',
        },
      ),
    );
