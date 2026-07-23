import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/plate_formatter.dart';
import '../../data/models/gov_data_model.dart';

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
        const SizedBox(height: 12),
        _StatsGrid(data: data),
        if (data.chassis.isNotEmpty) ...[
          const SizedBox(height: 12),
          _VinRow(vin: data.chassis),
        ],
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
          style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
        ),
      ],
    );
  }
}

/// A trust banner that makes the official source explicit — this is the whole
/// selling point of AutoProof, so we surface it prominently.
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
                        TextStyle(fontSize: 12, color: AppColors.tealText2)),
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
        style: const TextStyle(color: AppColors.white, fontSize: 12),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSubtle)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width row for the VIN / chassis number (too long for a grid tile).
class _VinRow extends StatelessWidget {
  const _VinRow({required this.vin});
  final String vin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag, size: 18, color: AppColors.textSubtle),
          const SizedBox(width: 8),
          const Text('מספר שלדה',
              style: TextStyle(fontSize: 12, color: AppColors.textSubtle)),
          const Spacer(),
          Text(
            vin,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 1,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
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
