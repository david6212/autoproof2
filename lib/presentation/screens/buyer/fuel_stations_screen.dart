import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/fuel_report.dart';
import '../../../data/models/fuel_station.dart';
import '../../providers/fuel_report_provider.dart';
import '../../providers/gov_api_provider.dart';
import '../../widgets/app_bar_action.dart';
import '../../widgets/app_card.dart';
import '../../widgets/map_sheet.dart';
import '../../widgets/fuel_report_sheet.dart';
import '../../widgets/map_cluster.dart';
import '../../widgets/skeleton.dart';
import 'inspectors_screen.dart' show userLocationProvider;

const _israelCenter = LatLng(31.7, 34.9);
const _distance = Distance();

/// Every legal public fuel station in Israel, on a map, nearest first.
///
/// **There are no prices here, and that is not an omission.** Israel publishes
/// no per-station fuel price anywhere: 95 octane is price-controlled and
/// therefore identical at every pump, and diesel is *not* controlled, so it
/// genuinely varies — and nobody publishes it. The only official figure that
/// exists is the refinery-gate reference shown at the top, which is a
/// wholesale number before excise and VAT, roughly half of what a driver pays.
/// It is labelled as such rather than dressed up as a pump price.
class FuelStationsScreen extends ConsumerStatefulWidget {
  const FuelStationsScreen({super.key});

  @override
  ConsumerState<FuelStationsScreen> createState() => _FuelStationsScreenState();
}

class _FuelStationsScreenState extends ConsumerState<FuelStationsScreen> {
  final _mapController = MapController();

  /// Drives the draggable sheet, so the app-bar action can move it to a stop
  /// rather than being a second, competing mechanism.
  final _sheetController = DraggableScrollableController();

  bool _movedToUser = false;
  double _zoom = 8;
  FuelStation? _selected;
  String _query = '';

  /// Sort by reported price instead of distance.
  bool _byPrice = false;

  /// Empty means "every company".
  final _companies = <String>{};

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// Sends the sheet to a stop. Used by the app-bar action, so keyboard and
  /// screen-reader users get the same reach as a drag.
  void _moveSheet(double size) {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      size,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  List<FuelStation> _filter(List<FuelStation> all) {
    final q = _query.trim();
    return all.where((s) {
      if (_companies.isNotEmpty && !_companies.contains(s.company)) return false;
      if (q.isEmpty) return true;
      return s.name.contains(q) ||
          s.city.contains(q) ||
          s.address.contains(q) ||
          s.company.contains(q);
    }).toList();
  }

  void _openCluster(MapCluster<FuelStation> cluster) {
    if (cluster.isSingle) {
      setState(() => _selected = cluster.single);
      _mapController.move(cluster.point, 15);
      // The tapped station is pinned to the TOP of the list, so if the sheet
      // is pulled right down the tap would have no visible answer. Raise it
      // just enough to show the card, and only if it is below that already —
      // never yank a sheet the user deliberately opened wide.
      if (_sheetController.isAttached &&
          _sheetController.size < kSheetInitial) {
        _moveSheet(kSheetInitial);
      }
      return;
    }
    final pts = cluster.points;
    final same = pts.every((p) =>
        (p.latitude - pts.first.latitude).abs() < 1e-6 &&
        (p.longitude - pts.first.longitude).abs() < 1e-6);
    if (same) {
      // fitCamera on a zero-extent set misbehaves; step in instead.
      _mapController.move(cluster.point, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(60),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fuelStationsProvider);
    final me = ref.watch(userLocationProvider).valueOrNull;

    ref.listen(userLocationProvider, (_, next) {
      final loc = next.valueOrNull;
      if (loc != null && !_movedToUser) {
        _movedToUser = true;
        _mapController.move(loc, 12);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('תחנות דלק'),
        actions: [
          AppBarAction(
            label: 'מפה מלאה',
            icon: Icons.open_in_full,
            onPressed: () => _moveSheet(kSheetMin),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _Loading(),
        error: (_, __) => const _Message(
          icon: Icons.cloud_off,
          text: 'לא ניתן לטעון את רשימת התחנות כרגע.\nבדקו את החיבור ונסו שוב.',
        ),
        data: (all) {
          final list = _filter(all);
          return Stack(
            children: [
              // The map fills the body rather than taking a fixed slice, so
              // whatever the sheet uncovers is real map underneath.
              Positioned.fill(child: _map(list, me)),
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: kSheetInitial,
                minChildSize: kSheetMin,
                maxChildSize: kSheetMax,
                // Snapping, so a drag lands somewhere deliberate instead of
                // leaving the sheet at whatever height a finger stopped at.
                snap: true,
                snapSizes: kSheetStops,
                builder: (context, scrollController) => MapSheet(
                  child: list.isEmpty
                      // Still scrollable: a non-scrolling child would leave
                      // the sheet draggable only by its handle.
                      ? ListView(
                          controller: scrollController,
                          children: const [
                            SizedBox(height: AppSpace.xxl),
                            _Message(
                              icon: Icons.search_off,
                              text: 'לא נמצאו תחנות שמתאימות לחיפוש.',
                            ),
                          ],
                        )
                      : _list(list, me, all, scrollController),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The handful of operators worth offering as chips — the long tail is
  /// reachable through search.
  List<String> _topCompanies(List<FuelStation> all) {
    final tally = <String, int>{};
    for (final s in all) {
      if (s.company.isNotEmpty) tally[s.company] = (tally[s.company] ?? 0) + 1;
    }
    final sorted = tally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(6)) e.key];
  }

  Widget _map(List<FuelStation> list, LatLng? me) {
    final cityMode = _zoom < kStreetZoom;
    final clusters = MapCluster.at<FuelStation>(_zoom, list);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: me ?? _israelCenter,
            initialZoom: me != null ? 12 : 8,
            onTap: (_, __) => setState(() => _selected = null),
            onPositionChanged: (camera, _) {
              // Clusters are computed per integer zoom, and this can fire
              // during layout — so the rebuild is deferred.
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
                  Marker(
                    point: cluster.point,
                    width: cluster.isSingle && !cityMode ? 38 : 62,
                    height: cluster.isSingle && !cityMode ? 38 : 46,
                    child: GestureDetector(
                      onTap: () => _openCluster(cluster),
                      child: cluster.isSingle && !cityMode
                          ? const _Pin()
                          : _Bubble(cluster: cluster),
                    ),
                  ),
                if (me != null)
                  Marker(point: me, width: 22, height: 22, child: const _MeDot()),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _list(
    List<FuelStation> list,
    LatLng? me,
    List<FuelStation> all,
    ScrollController scrollController,
  ) {
    final medians = ref.watch(fuelMediansProvider).valueOrNull ?? const {};
    final sorted = [...list];

    if (_byPrice) {
      // Only stations with a fresh report can be ranked by price at all, so
      // the unreported ones fall to the bottom rather than being silently
      // dropped — a station with no report is unknown, not expensive.
      sorted.sort((a, b) {
        final pa = medians[a.id], pb = medians[b.id];
        if (pa == null && pb == null) return 0;
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      });
    } else if (me != null) {
      sorted.sort((a, b) => _distance
          .as(LengthUnit.Meter, me, LatLng(a.lat!, a.lng!))
          .compareTo(
              _distance.as(LengthUnit.Meter, me, LatLng(b.lat!, b.lng!))));
    }

    final reported = medians.keys.where((k) => list.any((s) => s.id == k)).length;

    return ListView.separated(
      // The sheet's controller, not one of ours — this is what links a scroll
      // at the top of the list into a drag of the whole sheet.
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
      itemCount: sorted.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ReferencePriceCard(),
                const SizedBox(height: AppSpace.md),
                _Filters(
                  companies: _topCompanies(all),
                  selected: _companies,
                  query: _query,
                  onQuery: (v) => setState(() => _query = v),
                  onToggle: (c) => setState(() {
                    _companies.contains(c)
                        ? _companies.remove(c)
                        : _companies.add(c);
                  }),
                ),
                // The station tapped on the map, held at the top of the list
                // until it is dismissed — so a tap always has a visible answer
                // without covering the map.
                if (_selected != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  _StationCard(
                    station: _selected!,
                    me: me,
                    elevated: true,
                    onDismiss: () => setState(() => _selected = null),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                Row(
                  children: [
                    _SortChip(
                      label: 'הקרובות אליי',
                      on: !_byPrice,
                      enabled: me != null,
                      onTap: () => setState(() => _byPrice = false),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    _SortChip(
                      label: 'המחיר שדווח',
                      on: _byPrice,
                      enabled: reported > 0,
                      onTap: () => setState(() => _byPrice = true),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  _byPrice
                      // Never "the cheapest diesel" — only what drivers said,
                      // and only for the minority of stations anyone reported.
                      ? 'לפי המחיר הזול ביותר שדיווחו נהגים ב-14 הימים האחרונים · '
                          '$reported מתוך ${sorted.length} תחנות עם דיווח'
                      : '${sorted.length} תחנות · מקור: משרד האנרגיה'
                          '${me != null ? ' · ממוינות לפי קרבה אליך' : ''}',
                  style: context.text.captionSubtle,
                ),
              ],
            ),
          );
        }
        return _StationCard(station: sorted[i - 1], me: me);
      },
    );
  }
}

/// The one official price that exists, stated for exactly what it is.
class _ReferencePriceCard extends ConsumerWidget {
  const _ReferencePriceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref_ = ref.watch(dieselReferenceProvider).valueOrNull;
    if (ref_ == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
      child: AppCard(
        color: context.colors.tealLight,
        bordered: false,
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: context.colors.tealText2),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'סולר לתחבורה — ${ref_.shekelsPerLitre.toStringAsFixed(2)} ₪ לליטר '
                    'בשער בית הזיקוק (${ref_.monthLabel})',
                    style: AppText.bodySm.copyWith(
                        color: context.colors.tealText,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'מחיר סיטונאי לפני בלו ומע"מ, לא המחיר במשאבה. '
                    'מחירי סולר בפועל אינם מפוקחים ואינם מתפרסמים לפי תחנה.',
                    style: AppText.bodySm
                        .copyWith(color: context.colors.tealText2, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.companies,
    required this.selected,
    required this.query,
    required this.onQuery,
    required this.onToggle,
  });

  final List<String> companies;
  final Set<String> selected;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // No horizontal padding of its own: this now sits inside the list,
        // which already insets its content. Two paddings made a 32px gutter.
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xs),
          child: TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: 'חיפוש לפי עיר, שם תחנה או חברה…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: context.colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(color: context.colors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(color: context.colors.cardBorder),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            itemCount: companies.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (_, i) {
              final c = companies[i];
              final on = selected.contains(c);
              return GestureDetector(
                onTap: () => onToggle(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: AppSpace.xs),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? context.colors.tealFill : context.colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                        color: on
                            ? context.colors.tealFill
                            : context.colors.cardBorder),
                  ),
                  child: Text(
                    c,
                    style: AppText.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: on
                          ? context.colors.onBrand
                          : context.colors.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({
    required this.station,
    required this.me,
    this.elevated = false,
    this.onDismiss,
  });

  final FuelStation station;
  final LatLng? me;
  final bool elevated;

  /// Shown as a close button when the card is the answer to a map tap, so the
  /// pinned card can be cleared without hunting for the map again.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final away = me == null
        ? null
        : _distance.as(
            LengthUnit.Meter, me!, LatLng(station.lat!, station.lng!));
    final tally = ref.watch(fuelTallyProvider(station.id)).valueOrNull;

    return AppCard(
      elevated: elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(station.displayName, style: AppText.subtitle),
              ),
              if (away != null)
                Text(fmtDistance(away), style: context.text.captionBold),
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
          const SizedBox(height: 2),
          Text(station.fullAddress, style: context.text.bodySmMuted),
          const SizedBox(height: AppSpace.md),
          _DieselLine(tally: tally),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('ניווט'),
                  onPressed: () {
                    final q = '${station.lat},${station.lng}';
                    launchUrl(
                      Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$q'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  label: Text(tally?.myAgorot == null ? 'דווח מחיר' : 'עדכן'),
                  onPressed: () => showFuelReportSheet(
                    context,
                    ref,
                    station: station,
                    current: tally?.myAgorot,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the crowd says about diesel here — or an honest blank.
///
/// The price is never stated on its own. It always carries how many drivers
/// reported it and when, because a bare number reads as something the app is
/// vouching for, and the app checked nothing.
class _DieselLine extends StatelessWidget {
  const _DieselLine({required this.tally});
  final FuelPriceTally? tally;

  @override
  Widget build(BuildContext context) {
    final t = tally;
    final headline = t?.headline;

    if (headline == null) {
      return Row(
        children: [
          Icon(Icons.help_outline, size: 16, color: context.colors.textSubtle),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              t?.newestAt == null
                  ? 'אין דיווח על מחיר סולר בתחנה הזו'
                  : 'הדיווח האחרון כאן ישן מדי (${t!.ageLabel})',
              style: context.text.captionSubtle,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: context.colors.tealLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.local_gas_station,
              size: 16, color: context.colors.tealText2),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              headline,
              style: AppText.bodySm.copyWith(
                  color: context.colors.tealText,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (t != null && !t.isConfident)
            Tooltip(
              message: 'מעט דיווחים — ייתכן שאינו מייצג',
              child: Icon(Icons.info_outline,
                  size: 15, color: context.colors.tealText2),
            ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.local_gas_station,
        size: 30, color: context.colors.tealFill);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.cluster});
  final MapCluster<FuelStation> cluster;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm, vertical: AppSpace.xxs),
          decoration: BoxDecoration(
            color: context.colors.tealFill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: context.colors.onBrand, width: 1.5),
          ),
          child: Text('${cluster.count}',
              style: AppText.bodySm.copyWith(
                  color: context.colors.onBrand,
                  fontWeight: FontWeight.bold)),
        ),
        Text(
          cluster.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.tiny,
        ),
      ],
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D7FF9),
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.onBrand, width: 3),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
      itemBuilder: (_, __) => const Skeleton(height: 96, radius: AppRadius.lg),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.colors.textSubtle),
            const SizedBox(height: AppSpace.md),
            Text(text,
                textAlign: TextAlign.center, style: context.text.bodyMuted),
          ],
        ),
      ),
    );
  }
}

/// A two-state sort toggle. Disabled rather than hidden when it cannot apply,
/// so the option is discoverable before there is data behind it.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.on,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool on;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? context.colors.textSubtle
        : on
            ? context.colors.onBrand
            : context.colors.textMuted;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.xs + 2),
        decoration: BoxDecoration(
          color: on && enabled
              ? context.colors.tealFill
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: on && enabled
                  ? context.colors.tealFill
                  : context.colors.cardBorder),
        ),
        child: Text(label,
            style: AppText.bodySm
                .copyWith(fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}
