import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';

/// The app's standard surface: white, hairline border, [AppRadius.lg] corners.
///
/// This exact decoration was hand-written 24 times across 20 files before this
/// widget existed. Use it for any panel; pass [elevated] for floating overlays.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.margin,
    this.color = AppColors.white,
    this.radius = AppRadius.lg,
    this.bordered = true,
    this.elevated = false,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double radius;
  final bool bordered;
  final bool elevated;
  final VoidCallback? onTap;

  /// Set to [Clip.antiAlias] when children paint to the card's edge (a tinted
  /// header row, an image) so they follow the rounded corners.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: AppColors.cardBorder) : null,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? decorated
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: decorated,
            ),
    );
  }
}

/// Where a panel's content comes from. Shown as a badge so official records and
/// user-generated content can never be mistaken for one another
/// (BUSINESS_ROADMAP 9.3).
enum DataSource {
  /// Ministry of Transport records via data.gov.il.
  official,

  /// Reports, notes and ratings submitted by users.
  community,
}

/// An [AppCard] with the app's standard section header: a teal icon, a bold
/// title, an optional trailing badge, and an explanatory line underneath.
///
/// The car page's panels (official data, notes, encounters, journey, plate
/// history) all repeated this header by hand.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.margin,
    this.source,
  });

  final IconData icon;
  final String title;
  final Widget child;

  /// Labels the panel official or community. Omit for panels that present no
  /// factual claims (e.g. the buyer's own journey checklist).
  final DataSource? source;

  /// Short line under the title explaining what the panel is for.
  final String? subtitle;

  /// Badge or action shown at the end of the title row.
  final Widget? trailing;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.teal),
              const SizedBox(width: AppSpace.sm - 2),
              Expanded(child: Text(title, style: AppText.subtitle)),
              if (trailing != null) trailing!,
            ],
          ),
          if (source != null) ...[
            const SizedBox(height: AppSpace.sm - 2),
            DataSourceBadge(source: source!),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(subtitle!, style: AppText.caption),
          ],
          const SizedBox(height: AppSpace.md),
          child,
        ],
      ),
    );
  }
}

/// States whether a panel holds official records or user-submitted content.
class DataSourceBadge extends StatelessWidget {
  const DataSourceBadge({super.key, required this.source});

  final DataSource source;

  @override
  Widget build(BuildContext context) {
    // Blue = official record, orange = community report. Two different hues
    // (not two shades of the brand green) so the distinction survives a glance.
    final (bg, fg, icon, label) = switch (source) {
      DataSource.official => (
          AppColors.agentBlueBg,
          AppColors.agentBlue,
          Icons.account_balance,
          'מידע רשמי · משרד התחבורה',
        ),
      DataSource.community => (
          AppColors.dealerOrangeBg,
          AppColors.dealerOrange,
          Icons.groups_outlined,
          'מידע קהילתי · דיווחי משתמשים',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: source == DataSource.community
            ? Border.all(color: AppColors.cardBorder)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }
}

/// The app-wide liability notice. Show it at the foot of any screen that mixes
/// official records with user reports (BUSINESS_ROADMAP 9.11).
class LiabilityNotice extends StatelessWidget {
  const LiabilityNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, size: 15, color: AppColors.textSubtle),
          SizedBox(width: AppSpace.sm - 2),
          Expanded(
            child: Text(AppStrings.liabilityNotice, style: AppText.micro),
          ),
        ],
      ),
    );
  }
}

/// Small rounded count badge used next to section titles.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
      ),
      child: Text('$count',
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: AppColors.tealText)),
    );
  }
}
