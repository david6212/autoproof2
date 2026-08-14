
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/map_cluster.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/inspection_center.dart';
import '../../widgets/app_bar_action.dart';
import '../../widgets/app_card.dart';
import '../../widgets/map_sheet.dart';
import '../../providers/cars_provider.dart';
import '../../providers/gov_api_provider.dart';
import '../../../core/theme/app_text.dart';

/// The user's current position, or null if unavailable / permission denied.
/// Used to center the map and find the nearest inspection center.
final userLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
});

const _israelCenter = LatLng(31.7, 34.9);
const _distance = Distance();

/// Directory + live map of licensed pre-purchase inspection centers ("מכוני
/// בדיקה") from official Ministry of Transport data. Opens on a map centered on
/// the user's location so they can see which center is closest, Google-Maps
/// style, and switch to a distance-sorted list.
class InspectorsScreen extends ConsumerStatefulWidget {
  const InspectorsScreen({super.key, required this.carId});

  final String carId;

  @override
  ConsumerState<InspectorsScreen> createState() => _InspectorsScreenState();
}

class _InspectorsScreenState extends ConsumerState<InspectorsScreen> {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  String _query = '';
  /// The map is always on screen now, as a header above the list. This only
  /// grows it to fill the screen.
  bool _mapExpanded = false;
  bool _movedToUser = false;
  InspectionCenter? _selected;
  double _zoom = 7;

  @override
  void initState() {
    super.initState();
    final area =
        ref.read(carByIdProvider(widget.carId)).valueOrNull?.area.trim() ?? '';
    if (area.isNotEmpty) {
      _searchController.text = area;
      _query = area;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InspectionCenter> _filter(List<InspectionCenter> all) {
    final q = _query.trim();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.contains(q) ||
            c.city.contains(q) ||
            c.address.contains(q))
        .toList();
  }

  /// Distance from [me] to a center, or null if either is missing.
  double? _distanceTo(InspectionCenter c, LatLng? me) {
    if (me == null || !c.hasCoords) return null;
    return _distance.as(LengthUnit.Meter, me, LatLng(c.lat!, c.lng!));
  }

  void _goToNearest(List<InspectionCenter> centers, LatLng me) {
    InspectionCenter? best;
    double bestD = double.infinity;
    for (final c in centers) {
      final d = _distanceTo(c, me);
      if (d != null && d < bestD) {
        bestD = d;
        best = c;
      }
    }
    if (best != null) {
      _mapController.move(LatLng(best.lat!, best.lng!), 14);
      setState(() => _selected = best);
    }
  }

  @override
  Widget build(BuildContext context) {
    final centersAsync = ref.watch(inspectionCentersProvider);
    final me = ref.watch(userLocationProvider).valueOrNull;

    // Once the user's location arrives, glide the map to it (only in map mode).
    ref.listen(userLocationProvider, (_, next) {
      final loc = next.valueOrNull;
      if (loc != null && !_movedToUser) {
        _movedToUser = true;
        _mapController.move(loc, 12);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('מכוני בדיקת רכב'),
        actions: [
          AppBarAction(
            label: _mapExpanded ? 'הרשימה' : 'מפה מלאה',
            icon: _mapExpanded ? Icons.view_list_outlined : Icons.open_in_full,
            onPressed: () => setState(() => _mapExpanded = !_mapExpanded),
          ),
        ],
      ),
      body: SafeArea(
        child: centersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _Message(
              icon: Icons.cloud_off,
              text:
                  'לא ניתן לטעון את רשימת המכונים כרגע.\nבדקו את החיבור ונסו שוב.'),
          data: (all) {
            final list = _filter(all);
            return LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = mapHeaderHeight(
                  constraints.maxHeight,
                  expanded: _mapExpanded,
                );

                return Column(
                  children: [
                    // The map keeps every centre, even while a search narrows
                    // the list — otherwise typing a city name empties the map
                    // and there is nothing left to orient by.
                    SizedBox(
                      height: mapHeight,
                      child: _buildMap(list.isEmpty ? all : list, me),
                    ),
                    if (!_mapExpanded)
                      Expanded(
                        child: MapSheet(child: _buildList(list, me)),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Zooms into a tapped cluster so it breaks apart into its member centers.
  void _openCluster(MapCluster<InspectionCenter> cluster) {
    setState(() => _selected = null);
    final pts = cluster.points;
    // A lone center — or several sharing one coordinate — has no extent to fit,
    // so just fly to it at street zoom.
    final spread = pts.any((p) =>
        p.latitude != pts.first.latitude || p.longitude != pts.first.longitude);
    if (!spread) {
      _mapController.move(cluster.point, 15);
      if (cluster.isSingle) setState(() => _selected = cluster.single);
      return;
    }
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: pts,
      padding: const EdgeInsets.all(70),
      maxZoom: 16,
    ));
  }

  Widget _buildMap(List<InspectionCenter> list, LatLng? me) {
    final withCoords = list.where((c) => c.hasCoords).toList();
    final initial = me ??
        (withCoords.isNotEmpty
            ? LatLng(withCoords.first.lat!, withCoords.first.lng!)
            : _israelCenter);
    final initialZoom = me != null ? 12.0 : (withCoords.isNotEmpty ? 11.0 : 7.0);
    // Zoomed out: one labelled bubble per town (merged where they'd collide).
    // Zoomed in: individual street pins. Nothing overlaps at any zoom.
    final cityMode = _zoom < kStreetZoom;
    final clusters = MapCluster.at<InspectionCenter>(_zoom, withCoords);
    final anyClustered = cityMode || clusters.any((c) => !c.isSingle);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initial,
            initialZoom: initialZoom,
            onTap: (_, __) => setState(() => _selected = null),
            onPositionChanged: (camera, _) {
              // Clusters are computed per integer zoom level, so only rebuild
              // when that changes. The callback can fire during layout, so the
              // rebuild is deferred rather than calling setState mid-build.
              final changed = camera.zoom.round() != _zoom.round();
              _zoom = camera.zoom;
              if (changed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'il.autoproof.autoproof',
            ),
            MarkerLayer(
              markers: [
                for (final cluster in clusters)
                  if (cluster.isSingle && !cityMode)
                    Marker(
                      point: cluster.point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selected = cluster.single),
                        child: Icon(
                          Icons.location_on,
                          size: _selected?.id == cluster.single.id ? 40 : 32,
                          color: _selected?.id == cluster.single.id
                              ? context.colors.dealerOrange
                              : context.colors.teal,
                        ),
                      ),
                    )
                  else
                    Marker(
                      point: cluster.point,
                      width: 84,
                      height: 68,
                      child: GestureDetector(
                        onTap: () => _openCluster(cluster),
                        child: _ClusterBubble(cluster: cluster),
                      ),
                    ),
                if (me != null)
                  Marker(
                    point: me,
                    width: 22,
                    height: 22,
                    child: const _MeDot(),
                  ),
              ],
            ),
          ],
        ),
        if (anyClustered)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: _ZoomHint()),
          ),
        // Attribution (OSM tile usage requires credit).
        Positioned(
          bottom: 2,
          left: 4,
          child: Text('© OpenStreetMap',
              style: TextStyle(fontSize: 9.5, color: context.colors.textSubtle)),
        ),
        if (me != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'nearest',
                  backgroundColor: context.colors.tealFill,
                  foregroundColor: context.colors.onBrand,
                  onPressed: () => _goToNearest(list, me),
                  child: const Icon(Icons.near_me),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'me',
                  backgroundColor: context.colors.surface,
                  foregroundColor: context.colors.tealText2,
                  onPressed: () => _mapController.move(me, 13),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        if (me == null)
          const Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Center(child: _LocationHint()),
          ),
        // Only while the map fills the screen. In the split layout the tapped
        // centre is pinned to the top of the list instead — a card floating
        // over a third-height map covers the very pins it came from.
        if (_selected != null && _mapExpanded)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _CenterCard(
              center: _selected!,
              distance: _distanceTo(_selected!, me),
              elevated: true,
            ),
          ),
      ],
    );
  }

  Widget _buildList(List<InspectionCenter> list, LatLng? me) {
    // Sort by distance when we know where the user is.
    final sorted = [...list];
    if (me != null) {
      sorted.sort((a, b) {
        final da = _distanceTo(a, me) ?? double.infinity;
        final db = _distanceTo(b, me) ?? double.infinity;
        return da.compareTo(db);
      });
    }

    // The search moved in here with the list, so it is inside the sheet rather
    // than stacked above the map — the map is the header now.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchBar(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          _CenterCard(
            center: _selected!,
            distance: _distanceTo(_selected!, me),
            elevated: true,
            onDismiss: () => setState(() => _selected = null),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 8),
          child: Text(
            '${sorted.length} מכונים מורשים · מקור: משרד התחבורה'
            '${me != null ? ' · ממוינים לפי קרבה אליך' : ''}',
            style: TextStyle(fontSize: 12.5, color: context.colors.textSubtle),
          ),
        ),
      ],
    );

    if (sorted.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          header,
          const SizedBox(height: 24),
          _Message(
            icon: Icons.search_off,
            text: _query.trim().isEmpty
                ? 'לא נמצאו מכונים.'
                : 'לא נמצאו מכונים לחיפוש "${_query.trim()}".',
            actionLabel: _query.trim().isEmpty ? null : 'הצג הכל',
            onAction: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: sorted.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        final c = sorted[i - 1];
        return _CenterCard(center: c, distance: _distanceTo(c, me));
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'חיפוש לפי עיר או שם מכון…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: context.colors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Several nearby centers collapsed into one counted bubble. Tapping it zooms
/// in until the group breaks apart. Labelled with the city when the whole
/// cluster sits in one, so overlapping labels can't clutter dense areas.
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.cluster});
  final MapCluster<InspectionCenter> cluster;

  @override
  Widget build(BuildContext context) {
    final count = cluster.count;
    final size = count >= 10
        ? 46.0
        : count >= 5
            ? 41.0
            : 36.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.colors.teal,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.onBrand, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text('$count',
                style: TextStyle(
                    color: context.colors.onBrand,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            cluster.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: context.colors.tealText),
          ),
        ),
      ],
    );
  }
}

/// Nudge telling the user that zooming in reveals individual centers.
class _ZoomHint extends StatelessWidget {
  const _ZoomHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_in, size: 15, color: context.colors.teal),
          const SizedBox(width: 5),
          Text('הקישו על עיר או התקרבו כדי לראות את המכונים',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.colors.tealText)),
        ],
      ),
    );
  }
}

/// The blue "you are here" dot.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.agentBlue,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.onBrand, width: 3),
        boxShadow: [
          BoxShadow(
              color: context.colors.agentBlue.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2),
        ],
      ),
    );
  }
}

class _LocationHint extends StatelessWidget {
  const _LocationHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.warnBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off, size: 15, color: context.colors.warnText),
          const SizedBox(width: 6),
          Flexible(
            child: Text('אפשרו גישה למיקום כדי לראות את המכון הקרוב אליכם',
                style: TextStyle(fontSize: 12.5, color: context.colors.warnText)),
          ),
        ],
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  const _CenterCard({
    required this.center,
    this.distance,
    this.elevated = false,
    this.onDismiss,
  });

  final InspectionCenter center;
  final double? distance;
  final bool elevated;

  /// Shown as a close button when the card is the answer to a map tap, so the
  /// pinned card can be cleared without hunting for the map again.
  final VoidCallback? onDismiss;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח את הפעולה')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.only(bottom: elevated ? 0 : AppSpace.md),
      padding: const EdgeInsets.all(14),
      elevated: elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: context.colors.tealLight,
                child: Icon(Icons.build_circle_outlined,
                    color: context.colors.teal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: context.colors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: context.colors.textSubtle),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(center.fullAddress,
                              style: context.text.caption),
                        ),
                      ],
                    ),
                    if (center.hasCoords && !center.isExact) ...[
                      const SizedBox(height: 3),
                      Text('הסיכה במרכז העיר — התקשרו לכתובת המדויקת',
                          style: TextStyle(
                              fontSize: 11.5, color: context.colors.textSubtle)),
                    ],
                  ],
                ),
              ),
              if (distance != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.tealLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(fmtDistance(distance!),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: context.colors.tealText)),
                ),
              if (onDismiss != null)
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'סגור',
                  icon: Icon(Icons.close, color: context.colors.textSubtle),
                  onPressed: onDismiss,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (center.hasPhone)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: context.colors.tealFill,
                        minimumSize: const Size.fromHeight(44)),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('התקשר'),
                    onPressed: () => _launch(
                        context, Uri.parse('tel:${center.phoneDigits}')),
                  ),
                ),
              if (center.hasPhone) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.tealText2,
                    side: BorderSide(color: context.colors.teal),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('ניווט'),
                  onPressed: () => _launch(context, _mapsUri()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Prefer exact coordinates for navigation; fall back to a text search.
  Uri _mapsUri() {
    if (center.hasCoords) {
      return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${center.lat},${center.lng}');
    }
    return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(center.mapsQuery)}');
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.colors.textSubtle),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textMuted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
