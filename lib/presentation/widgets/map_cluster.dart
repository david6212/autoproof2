import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Anything the map can group: a coordinate plus the town it belongs to.
abstract class MapPoint {
  double? get lat;
  double? get lng;
  bool get hasCoords;

  /// The town. Below [kStreetZoom] a whole town becomes one node, so this is
  /// the grouping key, not just a label.
  String get city;
}

/// From this zoom on, each item gets its own pin so streets become useful.
/// Below it, items are grouped per city so the user sees how many each town
/// has.
const double kStreetZoom = 12.0;

/// How close two markers may sit (in screen pixels) before they merge. Both
/// are wider than the widest bubble (46px), which is what stops the pile-ups
/// that used to happen in dense areas like Gush Dan.
const double kCityRadiusPx = 64.0;
const double kStreetRadiusPx = 78.0;

/// "820 מ׳" under a kilometre, "3.4 ק״מ" above it. Shared by every map that
/// shows how far away something is.
String fmtDistance(double meters) => meters < 1000
    ? '${meters.round()} מ׳'
    : '${(meters / 1000).toStringAsFixed(1)} ק״מ';

/// Web-Mercator pixel position of a coordinate at a given integer zoom. Plain
/// maths on purpose — it is used only to measure on-screen distances, and
/// keeping it off the map library's API means the clustering can be unit
/// tested without a widget.
({double x, double y}) projectToPixels(double lat, double lng, int zoom) {
  final scale = 256.0 * (1 << zoom);
  final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
  return (
    x: (lng + 180) / 360 * scale,
    y: (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale,
  );
}

/// A group of items close enough on screen to share one marker. A cluster of
/// one renders as a normal pin; larger ones render as a counted bubble.
///
/// Extracted from the inspection-centres screen so the fuel-station map could
/// use it too. The algorithm is unchanged — it was verified against the real
/// coordinates for zero overlaps at every zoom, and that result only holds if
/// the maths stays exactly as it was. Only the element type became generic.
class MapCluster<T extends MapPoint> {
  MapCluster(this.items, this.point);

  final List<T> items;
  final LatLng point;

  int get count => items.length;
  bool get isSingle => count == 1;
  T get single => items.first;

  List<LatLng> get points => [for (final c in items) LatLng(c.lat!, c.lng!)];

  /// The city name when every member shares one, else null (mixed area).
  String? get soleCity {
    final city = items.first.city;
    return items.every((c) => c.city == city) ? city : null;
  }

  /// Caption under the bubble: the town itself, or — when neighbouring towns
  /// were folded in — the busiest one marked as a whole area.
  String get label {
    final sole = soleCity;
    if (sole != null) return sole;
    final tally = <String, int>{};
    for (final c in items) {
      tally[c.city] = (tally[c.city] ?? 0) + 1;
    }
    var best = items.first.city, top = 0;
    tally.forEach((city, n) {
      if (n > top) {
        top = n;
        best = city;
      }
    });
    return 'אזור $best';
  }

  static LatLng _centroid<T extends MapPoint>(List<T> group) {
    var lat = 0.0, lng = 0.0;
    for (final c in group) {
      lat += c.lat!;
      lng += c.lng!;
    }
    return LatLng(lat / group.length, lng / group.length);
  }

  /// What gets placed on the map before collision-merging: whole cities when
  /// zoomed out (so counts per town are visible), single items once zoomed in
  /// far enough for street positions to matter.
  static List<List<T>> _nodes<T extends MapPoint>(bool cityMode, List<T> items) {
    if (!cityMode) return [for (final c in items) [c]];
    final byCity = <String, List<T>>{};
    for (final c in items) {
      byCity.putIfAbsent(c.city, () => []).add(c);
    }
    return byCity.values.toList();
  }

  /// Groups [items] for display at [zoom], merging any two markers that would
  /// overlap on screen. Greedy and O(n²).
  static List<MapCluster<T>> at<T extends MapPoint>(double zoom, List<T> items) {
    final z = zoom.round().clamp(3, 18);
    final cityMode = zoom < kStreetZoom;
    final radius = cityMode ? kCityRadiusPx : kStreetRadiusPx;

    final nodes = _nodes(cityMode, items.where((c) => c.hasCoords).toList())
        .map((g) => (group: g, at: _centroid(g)))
        .toList()
      // Seed each cluster with the busiest node so bubbles settle on the
      // biggest town rather than an arbitrary neighbour.
      ..sort((a, b) => b.group.length.compareTo(a.group.length));

    final pts = [
      for (final n in nodes)
        (n: n, p: projectToPixels(n.at.latitude, n.at.longitude, z)),
    ];

    final taken = List<bool>.filled(pts.length, false);
    final clusters = <MapCluster<T>>[];
    final r2 = radius * radius;

    for (var i = 0; i < pts.length; i++) {
      if (taken[i]) continue;
      taken[i] = true;
      final group = [...pts[i].n.group];
      for (var j = i + 1; j < pts.length; j++) {
        if (taken[j]) continue;
        final dx = pts[i].p.x - pts[j].p.x;
        final dy = pts[i].p.y - pts[j].p.y;
        if (dx * dx + dy * dy <= r2) {
          taken[j] = true;
          group.addAll(pts[j].n.group);
        }
      }
      clusters.add(MapCluster<T>(group, _centroid(group)));
    }

    // Bigger clusters last so they paint on top of smaller ones.
    clusters.sort((a, b) => a.count.compareTo(b.count));
    return clusters;
  }
}
