import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/car_compare.dart';
import '../../../data/models/car_model.dart';
import '../../providers/compare_provider.dart';
import '../../providers/gov_api_provider.dart';
import '../../widgets/app_bar_action.dart';
import '../../widgets/app_card.dart';

/// Two or three shortlisted listings, side by side.
///
/// The columns are a table rather than three cards because the whole point is
/// reading ACROSS a row: 92,000 km next to 41,000 km is the comparison, and
/// three separate cards make the buyer hold the numbers in their head.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  /// Width of the row-label column. Narrow on purpose — the labels are short
  /// and every pixel here comes out of the columns being compared.
  static const _labelWidth = 76.0;

  /// Below this a column stops being readable, so the table scrolls sideways
  /// instead of squeezing further.
  static const _minCellWidth = 96.0;

  /// What the rows lose to chrome on each side: the list's padding plus the
  /// section card's 1px border. The header sits outside both, so it has to
  /// offset by the same amount or its columns stop lining up with the values
  /// underneath — and a comparison table whose headings are off by a column is
  /// worse than no table.
  static const _gutter = AppSpace.md + 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(compareSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => popOrHome(context),
        ),
        title: const Text('השוואת רכבים'),
        actions: [
          if (cars.isNotEmpty)
            AppBarAction(
              label: 'נקה',
              onPressed: () {
                ref.read(compareSelectionProvider.notifier).clear();
                popOrHome(context);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: cars.length < 2
            ? const _NotEnoughCars()
            : _CompareTable(cars: cars),
      ),
    );
  }
}

class _CompareTable extends ConsumerWidget {
  const _CompareTable({required this.cars});

  final List<CarModel> cars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One official lookup per plate. The family provider caches per plate, so
    // a car already opened elsewhere in the session costs nothing here.
    final lookups = [
      for (final c in cars) listingGov(ref, c),
    ];
    final gov = [for (final l in lookups) l.valueOrNull];
    final stillLoading = lookups.any((l) => l.isLoading);

    final sections = buildComparison(cars, gov: gov);

    return LayoutBuilder(
      builder: (context, constraints) {
        const chrome = CompareScreen._gutter * 2;
        final available =
            constraints.maxWidth - CompareScreen._labelWidth - chrome;
        final cellWidth = math.max(
          CompareScreen._minCellWidth,
          available / cars.length,
        );
        final tableWidth =
            CompareScreen._labelWidth + cellWidth * cars.length + chrome;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // Never narrower than the viewport, or the header and the rows
            // would sit in a column hugging the leading edge.
            width: math.max(tableWidth, constraints.maxWidth),
            child: Column(
              children: [
                _HeaderRow(cars: cars, cellWidth: cellWidth),
                if (stillLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xl),
                    children: [
                      for (final s in sections) ...[
                        _Section(section: s, cellWidth: cellWidth),
                        const SizedBox(height: AppSpace.md),
                      ],
                      const _NoScoreNote(),
                      const SizedBox(height: AppSpace.md),
                      const LiabilityNotice(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The pinned top row: each car's photo, name and price.
class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({required this.cars, required this.cellWidth});

  final List<CarModel> cars;
  final double cellWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.colors.cardBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
              width: CompareScreen._gutter + CompareScreen._labelWidth),
          for (final car in cars)
            SizedBox(
              width: cellWidth,
              child: _HeaderCell(car: car),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends ConsumerWidget {
  const _HeaderCell({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/car/${car.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: car.coverPhoto == null
                        ? Container(
                            color: context.colors.tealLight,
                            child: Icon(Icons.directions_car,
                                size: 24, color: context.colors.teal),
                          )
                        : CachedNetworkImage(
                            imageUrl: car.coverPhoto!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: context.colors.tealLight),
                            errorWidget: (_, __, ___) => Container(
                              color: context.colors.tealLight,
                              child: Icon(Icons.directions_car,
                                  size: 24, color: context.colors.teal),
                            ),
                          ),
                  ),
                ),
                PositionedDirectional(
                  top: -6,
                  end: -6,
                  child: IconButton(
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'הסר מההשוואה',
                    icon: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 12, color: context.colors.onBrand),
                    ),
                    onPressed: () => ref
                        .read(compareSelectionProvider.notifier)
                        .remove(car.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              car.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(fontWeight: FontWeight.bold),
            ),
            // The official section's badge belongs to the whole section, so a
            // demo column has to carry its own mark: without it, an invented
            // car sits under "מידע רשמי · משרד התחבורה" beside a real one.
            if (car.isDemo)
              Text(
                'מודעת הדגמה',
                textAlign: TextAlign.center,
                style: context.text.micro
                    .copyWith(color: context.colors.warnText),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.cellWidth});

  final CompareSection section;
  final double cellWidth;

  IconData get _icon => switch (section.id) {
        CompareSectionId.listing => Icons.sell_outlined,
        CompareSectionId.spec => Icons.build_outlined,
        CompareSectionId.official => Icons.account_balance,
      };

  @override
  Widget build(BuildContext context) {
    // A row nobody reported is dropped — nine columns of dashes is noise.
    final rows = section.rows.where((r) => !r.isEmpty).toList();

    // The official section is the exception. Hiding it when the registry
    // returned nothing would make "we checked and found no record" look
    // identical to "this was never checked", and the second is the reading a
    // buyer must never be given.
    final isOfficial = section.id == CompareSectionId.official;
    if (rows.isEmpty && !isOfficial) return const SizedBox.shrink();

    return AppCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon, size: 16, color: context.colors.teal),
                    const SizedBox(width: AppSpace.sm - 2),
                    // Expanded: "רשומות משרד התחבורה" is 1.8px too wide for a
                    // two-column table on a 360px phone.
                    Expanded(
                      child: Text(section.title, style: AppText.subtitle),
                    ),
                  ],
                ),
                if (section.id == CompareSectionId.official) ...[
                  const SizedBox(height: AppSpace.sm - 2),
                  const DataSourceBadge(source: DataSource.official),
                ],
                if (section.note != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(section.note!, style: context.text.micro),
                ],
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, 0, AppSpace.md, AppSpace.md),
              child: Text(
                'לא נמצאו רשומות במרשם עבור הרכבים האלה.',
                style: context.text.captionSubtle,
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _TableRow(
                row: rows[i],
                cellWidth: cellWidth,
                // Zebra striping: with three columns of numbers the eye loses
                // the row it is on halfway across.
                striped: i.isEven,
              ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.cellWidth,
    required this.striped,
  });

  final CompareRow row;
  final double cellWidth;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: striped ? context.colors.background : null,
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: CompareScreen._labelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Text(row.label, style: context.text.micro),
            ),
          ),
          for (var i = 0; i < row.cells.length; i++)
            SizedBox(
              width: cellWidth,
              child: _Cell(
                cell: row.cells[i],
                isBest: row.best.contains(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.isBest});

  final CompareCell cell;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    // Precedence, deliberately: a warning outranks an advantage. The cheapest
    // of three cars is still the one with the recorded structural change, and
    // a green "best price" pill on that cell would bury the thing that matters.
    final (bg, fg, bold) = switch ((cell.tone, isBest)) {
      (CellTone.bad, _) => (
          context.colors.errorBg,
          context.colors.errorRed,
          true,
        ),
      (_, true) => (
          context.colors.tealLight,
          context.colors.tealText,
          true,
        ),
      (CellTone.good, false) => (null, context.colors.tealText2, false),
      _ => (null, context.colors.textPrimary, false),
    };

    final text = Text(
      cell.text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppText.bodySm.copyWith(
        color: cell.isKnown ? fg : context.colors.textSubtle,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );

    if (bg == null || !cell.isKnown) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: text,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: text,
      ),
    );
  }
}

/// States plainly that the table does not pick a winner, so the highlighted
/// cells are not mistaken for a recommendation.
class _NoScoreNote extends StatelessWidget {
  const _NoScoreNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: context.colors.textSubtle),
          const SizedBox(width: AppSpace.sm - 2),
          Expanded(
            child: Text(
              'הסימון הירוק מציין את הערך העדיף בשורה אחת בלבד. '
              'האפליקציה לא מדרגת רכבים ולא ממליצה על אחד מהם — '
              'שקלול בין מחיר להיסטוריה הוא שיקול שלכם.',
              style: context.text.micro,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotEnoughCars extends StatelessWidget {
  const _NotEnoughCars();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows,
                size: 56, color: context.colors.textSubtle),
            const SizedBox(height: AppSpace.md),
            const Text('צריך לפחות שני רכבים להשוואה',
                style: AppText.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(
              'בחרו רכבים מהרשימה השמורה ולחצו "השווה".',
              style: context.text.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: context.colors.tealFill),
              onPressed: () => context.go('/saved'),
              child: const Text('לרכבים השמורים'),
            ),
          ],
        ),
      ),
    );
  }
}
