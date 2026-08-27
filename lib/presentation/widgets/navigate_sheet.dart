import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';

/// "Take me there" — for a fuel station, an inspection centre, a garage.
///
/// The maps in this app could show you where something was and then leave you
/// to type the address into another app yourself. A screen that knows the
/// destination and makes you re-enter it is doing half a job.
///
/// **Waze is offered first, and that is not a coin toss.** In Israel it is the
/// navigation app most drivers actually have open in the car. Google Maps sits
/// beside it for everyone else, and Apple Maps appears only on iOS, where it
/// is the system default.
///
/// Every link is an `https://` universal link rather than a `waze://` or
/// `comgooglemaps://` scheme. Two reasons: a scheme that no installed app
/// claims fails silently, whereas the https form falls back to the website; and
/// on Android 11+ probing custom schemes needs a `<queries>` block in the
/// manifest, which is a permission-shaped thing to add for no gain.
class NavigateSheet extends StatelessWidget {
  const NavigateSheet._({
    required this.destination,
    required this.isCoords,
    required this.label,
  });

  /// Already resolved to either "lat,lng" or a search string.
  final String destination;

  /// Whether [destination] is a coordinate pair. Waze takes coordinates in
  /// `ll` and free text in `q`, and handing coordinates to `q` turns an exact
  /// destination into a search that may well find something else.
  final bool isCoords;

  /// What the reader is being taken to, shown at the top so a mistap is
  /// obvious before an app opens.
  final String label;

  /// Israel's bounding box, the same one `FuelStation.plausible` uses.
  ///
  /// **This exists because of a real trap.** A garage added by the community
  /// is stored with `lat: 0, lng: 0` — the add-place screen says outright that
  /// it does not capture a location yet. Navigating to those coordinates sends
  /// somebody to the Atlantic off West Africa, and it would do it confidently.
  /// Coordinates are used only when they are inside the country; otherwise the
  /// destination becomes the name and the town, which the navigation app can
  /// search for the way a person would.
  static bool _inIsrael(double? lat, double? lng) =>
      lat != null &&
      lng != null &&
      lat > 29.4 &&
      lat < 33.4 &&
      lng > 34.2 &&
      lng < 35.9;

  /// What will actually be handed to a navigation app.
  ///
  /// Exposed so the 0,0 case can be asserted directly. It is the one failure
  /// here that would not look like a failure: every button would work, every
  /// app would open, and the driver would be sent to the Atlantic.
  @visibleForTesting
  static ({String destination, bool isCoords}) destinationFor({
    double? lat,
    double? lng,
    required String query,
  }) {
    final coords = _inIsrael(lat, lng);
    return (
      destination: coords ? '$lat,$lng' : query.trim(),
      isCoords: coords,
    );
  }

  /// Opens the chooser. [query] is the human description — a name and a town —
  /// used when there are no usable coordinates.
  static Future<void> show(
    BuildContext context, {
    double? lat,
    double? lng,
    required String query,
    required String label,
  }) {
    final resolved = destinationFor(lat: lat, lng: lng, query: query);

    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => NavigateSheet._(
        destination: resolved.destination,
        isCoords: resolved.isCoords,
        label: label,
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      // Said out loud rather than swallowed: a button that does nothing reads
      // as a broken app, and the reader can still navigate by hand.
      messenger.showSnackBar(
        const SnackBar(content: Text('לא הצלחנו לפתוח אפליקציית ניווט.')),
      );
    }
    if (navigator.canPop()) navigator.pop();
  }

  bool get _isApple => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final encoded = Uri.encodeComponent(destination);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ניווט אל', style: AppText.subtitle),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption,
                  ),
                ],
              ),
            ),
            _Option(
              label: 'Waze',
              icon: Icons.navigation_rounded,
              onTap: () => _open(
                context,
                Uri.parse('https://waze.com/ul'
                    '?${isCoords ? "ll" : "q"}=$encoded&navigate=yes'),
              ),
            ),
            _Option(
              label: 'Google Maps',
              icon: Icons.map_rounded,
              onTap: () => _open(
                context,
                Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$encoded'),
              ),
            ),
            if (_isApple)
              _Option(
                label: 'Apple Maps',
                icon: Icons.pin_drop_rounded,
                onTap: () => _open(
                  context,
                  Uri.parse('https://maps.apple.com/?daddr=$encoded&dirflg=d'),
                ),
              ),
            const SizedBox(height: AppSpace.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ביטול',
                  style: TextStyle(color: colors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.tealLight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 21, color: colors.tealText2),
      ),
      // Latin app names in an RTL sheet: pinned, so "Google Maps" never
      // reorders into "Maps Google".
      title: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(label, style: AppText.title),
        ),
      ),
      trailing: Icon(Icons.chevron_left, color: colors.textSubtle),
    );
  }
}
