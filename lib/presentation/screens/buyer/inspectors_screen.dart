import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/inspection_center.dart';
import '../../providers/cars_provider.dart';
import '../../providers/gov_api_provider.dart';

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

String _fmtDistance(double meters) => meters < 1000
    ? '${meters.round()} מ׳'
    : '${(meters / 1000).toStringAsFixed(1)} ק״מ';

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
  bool _mapMode = true;
  bool _movedToUser = false;
  InspectionCenter? _selected;

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
      if (loc != null && !_movedToUser && _mapMode) {
        _movedToUser = true;
        _mapController.move(loc, 12);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('מכוני בדיקת רכב'),
        actions: [
          IconButton(
            tooltip: _mapMode ? 'רשימה' : 'מפה',
            icon: Icon(_mapMode ? Icons.view_list_outlined : Icons.map_outlined),
            onPressed: () => setState(() => _mapMode = !_mapMode),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: centersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _Message(
                    icon: Icons.cloud_off,
                    text:
                        'לא ניתן לטעון את רשימת המכונים כרגע.\nבדקו את החיבור ונסו שוב.'),
                data: (all) {
                  final list = _filter(all);
                  if (list.isEmpty) {
                    return _Message(
                      icon: Icons.search_off,
                      text: _query.trim().isEmpty
                          ? 'לא נמצאו מכונים.'
                          : 'לא נמצאו מכונים לחיפוש "${_query.trim()}".',
                      actionLabel: _query.trim().isEmpty ? null : 'הצג הכל',
                      onAction: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    );
                  }
                  return _mapMode
                      ? _buildMap(list, me)
                      : _buildList(list, me);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(List<InspectionCenter> list, LatLng? me) {
    final withCoords = list.where((c) => c.hasCoords).toList();
    final initial = me ??
        (withCoords.isNotEmpty
            ? LatLng(withCoords.first.lat!, withCoords.first.lng!)
            : _israelCenter);
    final initialZoom = me != null ? 12.0 : (withCoords.isNotEmpty ? 11.0 : 7.0);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initial,
            initialZoom: initialZoom,
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'md.autoproof',
            ),
            MarkerLayer(
              markers: [
                for (final c in withCoords)
                  Marker(
                    point: LatLng(c.lat!, c.lng!),
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = c),
                      child: Icon(
                        Icons.location_on,
                        size: _selected?.id == c.id ? 40 : 32,
                        color: _selected?.id == c.id
                            ? AppColors.dealerOrange
                            : AppColors.teal,
                      ),
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
        // Attribution (OSM tile usage requires credit).
        const Positioned(
          bottom: 2,
          left: 4,
          child: Text('© OpenStreetMap',
              style: TextStyle(fontSize: 9, color: AppColors.textSubtle)),
        ),
        if (me != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'nearest',
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  onPressed: () => _goToNearest(list, me),
                  child: const Icon(Icons.near_me),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'me',
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.teal,
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
            child: _LocationHint(),
          ),
        if (_selected != null)
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: sorted.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 2),
            child: Text(
              '${sorted.length} מכונים מורשים · מקור: משרד התחבורה'
              '${me != null ? ' · ממוינים לפי קרבה אליך' : ''}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
          );
        }
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
          fillColor: AppColors.background,
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

/// The blue "you are here" dot.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.agentBlue,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: AppColors.agentBlue.withValues(alpha: 0.4),
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
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_off, size: 15, color: AppColors.warnText),
          SizedBox(width: 6),
          Expanded(
            child: Text('אפשרו גישה למיקום כדי לראות את המכון הקרוב אליכם',
                style: TextStyle(fontSize: 12, color: AppColors.warnText)),
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
  });

  final InspectionCenter center;
  final double? distance;
  final bool elevated;

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
    return Container(
      margin: EdgeInsets.only(bottom: elevated ? 0 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: elevated
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.tealLight,
                child: Icon(Icons.build_circle_outlined,
                    color: AppColors.teal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(center.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textSubtle),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(center.fullAddress,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_fmtDistance(distance!),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tealText)),
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
                        backgroundColor: AppColors.teal,
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
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
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
            Icon(icon, size: 44, color: AppColors.textSubtle),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
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
