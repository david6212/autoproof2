import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/plate_formatter.dart';
import '../../data/models/gov_data_model.dart';

/// Displays official government vehicle data: dark header, 2×2 stat grid,
/// usage-type banner (green private / red commercial), safety, disclaimer.
class GovDataCard extends StatelessWidget {
  const GovDataCard({super.key, required this.data});

  final GovData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(data: data),
        const SizedBox(height: 12),
        _StatsGrid(data: data),
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
          Row(
            children: [
              _Chip(text: PlateFormatter.withDashes(data.plate)),
              const SizedBox(width: 8),
              _Chip(text: data.fuelType),
              if (data.trim.isNotEmpty) ...[
                const SizedBox(width: 8),
                _Chip(text: data.trim),
              ],
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
