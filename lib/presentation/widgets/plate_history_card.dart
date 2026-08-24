import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/odometer_check.dart';
import '../../data/models/car_model.dart';
import '../../data/models/plate_snapshot_model.dart';
import '../providers/cars_provider.dart';
import '../providers/gov_api_provider.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';

/// Odometer cross-check + cross-listing memory for a plate. Compares the
/// current listing's km against BOTH the official gov odometer (last test) and
/// this plate's past BonnetCheck listings, flagging a rollback (any earlier
/// reading higher than now). Renders nothing when there's nothing to compare.
class PlateHistoryCard extends ConsumerWidget {
  const PlateHistoryCard({
    super.key,
    required this.car,
    this.showRollbackBanner = true,
  });

  /// The listing itself, because both halves of this comparison now travel
  /// with it: the registry's answer (`govSnapshot`) and this plate's earlier
  /// listings (`plateHistorySnapshot`). A buyer holds no plate to look either
  /// one up with, which is the whole point of taking it out of the public
  /// document.
  final CarModel car;

  /// Whether to repeat the mismatch banner inside this card.
  ///
  /// False on the listing page, where the findings block above already states
  /// it and this card is the evidence you scroll to. True everywhere else, so
  /// the card still stands on its own.
  final bool showRollbackBanner;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = [
      for (final m in car.plateHistorySnapshot ?? const <Map<String, dynamic>>[])
        PlateSnapshot.fromMap(m),
    ];
    final govData = listingGov(ref, car).valueOrNull;

    final currentKm = car.km;
    final previous = history.where((s) => s.carId != car.id).toList();
    // Same rule the findings block at the top of the page reads, so the two
    // can never disagree about the same two numbers.
    final govKm = OdometerCheck.officialReading(govData?.lastTestKm);
    final govRollback =
        OdometerCheck.belowOfficial(officialKm: govKm, currentKm: currentKm);
    final histRollback = OdometerCheck.belowPastListings(
        previous: previous, currentKm: currentKm);

    // Nothing to show if there's neither an official reading nor prior listings.
    if (govKm == null && previous.isEmpty) return const SizedBox.shrink();

    return AppSectionCard(
      icon: Icons.speed,
      title: 'בדיקת קילומטראז\' והיסטוריה',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rollback warning (from official record and/or a past listing).
          // Suppressed when the page already leads with it — see
          // [showRollbackBanner].
          if (showRollbackBanner && (govRollback || histRollback)) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.errorBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: context.colors.errorRed),
                  const SizedBox(width: 8),
                  // Factual description only. "חשד לגלגול" implied a criminal
                  // act; a mismatch between sources is what we can actually
                  // show, and the reader draws their own conclusion.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          govRollback
                              ? 'נמצאה אי-התאמה בין נתוני הקילומטראז\' במקורות שונים: המודעה מציגה פחות ק"מ מהרישום בטסט האחרון.'
                              : 'נמצאה אי-התאמה בין נתוני הקילומטראז\' במקורות שונים: במודעה קודמת נרשמו יותר ק"מ מהמודעה הנוכחית.',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: context.colors.errorRed),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'מומלץ לבדוק את היסטוריית הרכב לפני השלמת העסקה.',
                          style: TextStyle(
                              fontSize: 11.5, color: context.colors.errorRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Official odometer (from the last annual test).
          if (govKm != null)
            _kmRow(
              context,
              icon: Icons.verified_user,
              // Naming the source is a licence obligation, not just nice-to-have.
              label: 'מד-אוץ רשמי · משרד התחבורה (טסט אחרון)',
              km: govKm,
              flagged: govRollback,
              okNote: 'תואם ✓',
            ),

          // Past listings are SUMMARISED, never itemised. Listing every past
          // price and reading builds a timeline of the car's owners; a count
          // plus the direction of change gives the buyer the same signal
          // without publishing that history.
          if (previous.isNotEmpty) ...[
            if (govKm != null) const SizedBox(height: 6),
            const SizedBox(height: 6),
            _summaryRow(
              context,
              icon: Icons.history,
              label: previous.length == 1
                  ? 'נמצאה מודעה קודמת אחת באפליקציה'
                  : 'נמצאו ${previous.length} מודעות קודמות באפליקציה',
            ),
            if (_priceNote(previous) case final note?)
              _summaryRow(context, icon: Icons.swap_vert, label: note),
            if (_kmNote(previous, currentKm) case final note?)
              _summaryRow(
              context,
                  icon: Icons.speed, label: note, flagged: histRollback),
          ],
          // Every surface carrying community-derived data offers a way to
          // challenge it.
          if (previous.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('דווח על מידע שגוי',
                    style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.textMuted,
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _reportWrong(context, ref),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _reportWrong(BuildContext context, WidgetRef ref) async {
    await ref
        .read(submitCorrectionProvider)
        .call(kind: 'plate_history', carId: car.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הבקשה נשלחה לבדיקה. תודה.')),
      );
    }
  }

  /// "The asking price rose/fell since the previous listing" — direction and
  /// size only, never the old figures themselves.
  static String? _priceNote(List<PlateSnapshot> previous) {
    final last = previous.first.price;
    final diff = last - previous.last.price;
    if (previous.length < 2 || diff == 0) return null;
    final amount = _fmt.format(diff.abs());
    return diff > 0
        ? 'המחיר המבוקש עלה בכ-₪$amount בין המודעות'
        : 'המחיר המבוקש ירד בכ-₪$amount בין המודעות';
  }

  /// Whether the reading moved forward as expected, without listing each one.
  static String? _kmNote(List<PlateSnapshot> previous, int currentKm) {
    final highest = previous.map((s) => s.km).reduce((a, b) => a > b ? a : b);
    if (highest > currentKm) {
      return 'במודעה קודמת נרשמו ${_fmt.format(highest)} ק"מ — יותר מהמודעה הנוכחית';
    }
    return 'הקילומטראז\' עלה בהתאמה בין המודעות ✓';
  }

  /// A single summarised line — no odometer column, no price column.
  Widget _summaryRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool flagged = false,
  }) {
    final color = flagged ? context.colors.errorRed : context.colors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: flagged ? context.colors.errorRed : context.colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _kmRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int km,
    required bool flagged,
    String? okNote,
    String? trailing,
  }) {
    final kmColor = flagged ? context.colors.errorRed : context.colors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: flagged ? context.colors.errorRed : context.colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: context.text.caption),
          ),
          Text('${_fmt.format(km)} ק"מ',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kmColor)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing,
                style: context.text.caption),
          ] else if (okNote != null && !flagged) ...[
            const SizedBox(width: 8),
            Text(okNote,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: context.colors.teal)),
          ],
        ],
      ),
    );
  }
}
