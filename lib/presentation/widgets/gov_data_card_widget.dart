import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/plate_formatter.dart';
import '../../data/models/gov_data_model.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';

/// Displays official government vehicle data:
/// official-source banner → dark header → license-validity strip →
/// 2×2 stat grid → VIN → usage-type banner → safety → disclaimer.
class GovDataCard extends StatelessWidget {
  const GovDataCard({super.key, required this.data});

  final GovData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SourceBanner(),
        const SizedBox(height: 12),
        _Header(data: data),
        const SizedBox(height: 12),
        _ValidityStrip(expiry: data.licenseExpiry),
        // Critical: vehicle scrapped / finally cancelled.
        if (data.offRoad) ...[
          const SizedBox(height: 12),
          _WarnBanner(
            icon: Icons.block,
            text: data.offRoadDate.isEmpty
                ? 'הרכב ירד מהכביש / בוטל סופית'
                : 'הרכב ירד מהכביש / בוטל סופית · ${data.offRoadDate}',
          ),
        ],
        // High-priority flags from the history + recall datasets.
        if (data.recalls.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecallBanner(recalls: data.recalls),
        ],
        if (data.structuralChange) ...[
          const SizedBox(height: 12),
          const _WarnBanner(
            icon: Icons.warning_amber_rounded,
            text: 'בוצע שינוי מבנה ברכב (מדווח למשרד התחבורה)',
          ),
        ],
        if (data.lastTestKm != null) ...[
          const SizedBox(height: 12),
          _OdometerCard(km: data.lastTestKm!),
        ],
        const SizedBox(height: 12),
        _StatsGrid(data: data),
        const SizedBox(height: 12),
        _FullSpecs(data: data),
        const SizedBox(height: 12),
        _UsageBanner(data: data),
        if (data.safetyRating != null) ...[
          const SizedBox(height: 12),
          _SafetyCard(rating: data.safetyRating!),
        ],
        const SizedBox(height: 16),
        const Text(
          AppStrings.govDisclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
        ),
      ],
    );
  }
}

/// Official odometer reading from the last annual test — a key anti-fraud
/// signal for used-car buyers.
class _OdometerCard extends StatelessWidget {
  const _OdometerCard({required this.km});
  final int km;

  static final _fmt = NumberFormat('#,###', 'en');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.speed, color: AppColors.teal),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('מד אוץ רשמי (בטסט האחרון)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.tealText)),
          ),
          Text('${_fmt.format(km)} ק"מ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.tealText)),
        ],
      ),
    );
  }
}

/// A red warning banner (structural change, etc.).
class _WarnBanner extends StatelessWidget {
  const _WarnBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Lists open manufacturer recalls (service calls not yet performed).
class _RecallBanner extends StatelessWidget {
  const _RecallBanner({required this.recalls});
  final List<RecallItem> recalls;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: AppColors.errorRed),
              const SizedBox(width: 8),
              Text('ריקול פתוח · ${recalls.length} קריאות שירות שלא בוצעו',
                  style: const TextStyle(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          for (final r in recalls.take(4)) ...[
            const SizedBox(height: 8),
            Text(
              '• ${r.system.isNotEmpty ? '${r.system}: ' : ''}${r.description}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.errorRed),
            ),
          ],
        ],
      ),
    );
  }
}

/// A trust banner that makes the official source explicit — this is the whole
/// selling point of OtoV, so we surface it prominently.
class _SourceBanner extends StatelessWidget {
  const _SourceBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user,
                color: AppColors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('נתונים רשמיים · משרד התחבורה',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.tealText)),
                SizedBox(height: 2),
                Text('מקור: מרשם הרכב הממשלתי (data.gov.il)',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.tealText2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final GovData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.tealDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.year} · ${data.color}',
            style: const TextStyle(color: AppColors.tealLight, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(text: PlateFormatter.withDashes(data.plate)),
              _Chip(text: data.fuelType),
              if (data.trim.isNotEmpty) _Chip(text: data.trim),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.white, fontSize: 12.5),
      ),
    );
  }
}

/// Computes and shows whether the vehicle's license (annual test) is currently
/// valid, based on the official expiry date. This is the "is it road-legal
/// right now" signal a buyer cares about most.
class _ValidityStrip extends StatelessWidget {
  const _ValidityStrip({required this.expiry});
  final DateTime? expiry;

  @override
  Widget build(BuildContext context) {
    if (expiry == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final valid = expiry!.isAfter(now);
    final days = expiry!.difference(now).inDays;
    final dateStr =
        '${expiry!.day.toString().padLeft(2, '0')}/${expiry!.month.toString().padLeft(2, '0')}/${expiry!.year}';

    // Green when valid, orange when expiring within 30 days, red when expired.
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;

    if (!valid) {
      bg = AppColors.errorBg;
      fg = AppColors.errorRed;
      icon = Icons.cancel_outlined;
      label = 'רישיון פג תוקף · $dateStr';
    } else if (days <= 30) {
      bg = AppColors.warnBg;
      fg = AppColors.warnText;
      icon = Icons.access_time;
      label = 'הרישיון פג בעוד $days ימים · $dateStr';
    } else {
      bg = AppColors.tealLight;
      fg = AppColors.tealText;
      icon = Icons.check_circle;
      label = 'רישיון בתוקף · עד $dateStr';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});
  final GovData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('בעלות', data.ownershipType.isEmpty ? '—' : data.ownershipType),
      ('טסט אחרון', data.lastTestDisplay),
      ('תוקף רישיון', data.licenseExpiryDisplay),
      ('דגם', data.model.isEmpty ? '—' : data.model),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        for (final it in items) _StatTile(label: it.$1, value: it.$2),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSubtle)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.title,
          ),
        ],
      ),
    );
  }
}

/// Full-width row for the VIN / chassis number (too long for a grid tile).
/// Full table of every field the Ministry of Transport provides.
class _FullSpecs extends StatelessWidget {
  const _FullSpecs({required this.data});
  final GovData data;

  @override
  Widget build(BuildContext context) {
    // (label, value, ltr?) — only non-empty rows are shown.
    final rows = <(String, String, bool)>[
      ('יצרן', data.make, false),
      ('דגם מסחרי',
          data.commercialName.isNotEmpty ? data.commercialName : data.model,
          true),
      ('קוד דגם', data.model, true),
      ('רמת גימור', data.trim, true),
      ('שנת ייצור', data.year > 0 ? '${data.year}' : '', false),
      ('עלייה לכביש', data.firstOnRoadDisplay, false),
      ('צבע', data.color, false),
      ('סוג דלק', data.fuelType, false),
      ('דגם מנוע', data.engineModel, true),
      ('קבוצת זיהום', data.pollutionGroup, false),
      ('בעלות', data.ownershipType, false),
      ('מקוריות', data.originality, false),
      ('רישום ראשון', data.firstRegistration, false),
      ('שינוי צבע רשום', data.colorChanged ? 'כן' : '', false),
      ('שינוי צמיגים רשום', data.tireChanged ? 'כן' : '', false),
      ('תג חניה לנכה', data.hasDisabilityTag ? 'כן' : '', false),
      ('טסט אחרון', data.lastTestDisplay, false),
      ('תוקף רישיון', data.licenseExpiryDisplay, false),
      ('רמת אבזור בטיחותי', data.safetyRating ?? '', false),
      ('צמיג קדמי', data.frontTire, true),
      ('צמיג אחורי', data.rearTire, true),
      ('מספר שלדה', data.chassis, true),
    ].where((r) => r.$2.isNotEmpty && r.$2 != '—').toList();

    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.tealLight,
            child: const Text('כל הפרטים הרשמיים',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.tealText)),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              color: i.isOdd ? AppColors.background : AppColors.white,
              child: Row(
                children: [
                  Text(rows[i].$1,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.end,
                      textDirection:
                          rows[i].$3 ? TextDirection.ltr : TextDirection.rtl,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UsageBanner extends StatelessWidget {
  const _UsageBanner({required this.data});
  final GovData data;

  @override
  Widget build(BuildContext context) {
    final private = data.isPrivate;
    final bg = private ? AppColors.tealLight : AppColors.errorBg;
    final fg = private ? AppColors.tealText : AppColors.errorRed;
    final icon = private ? Icons.check_circle : Icons.warning_amber_rounded;
    final label = private
        ? 'רכב פרטי'
        : 'שימוש מסחרי: ${data.ownershipType}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.rating});
  final String rating;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md,
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.teal),
          const SizedBox(width: 10),
          const Text('רמת אבזור בטיחותי: ',
              style: TextStyle(color: AppColors.textMuted)),
          Expanded(
            child: Text(
              rating,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
