import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';

/// A manufacturer's mark, for the make filter.
///
/// **NOT WIRED UP.** Nothing renders this yet; the filter shows plain text.
/// It is kept because it holds the two findings that a future attempt would
/// otherwise have to rediscover.
///
/// **1 — the marques are trademarks.** BUSINESS_ROADMAP 9.9 already lists
/// permission for artwork we do not own as an open question, so no logo file
/// is downloaded or bundled here. To turn this on: obtain licensed files,
/// save them as `assets/makes/<slug>.png` (slug = [assetSlug]), declare the
/// folder in pubspec.yaml, set [hasAssets] to true, and render this beside
/// each make in `search_filter_sheet.dart`. A make with no file falls back
/// rather than leaving a gap.
///
/// **2 — a letter monogram is not a usable substitute.** Measured against the
/// 28 makes in `kCarCatalog`: one Hebrew initial collides badly — ס covers
/// סקודה, סוזוקי, סיטרואן, סיאט and סובארו; מ covers four; א covers three.
/// Latin initials are no better (M is מאזדה, מרצדס, מיני, מיצובישי and MG).
/// Three letters is the first length that separates them all, and at that
/// point it is an abbreviation rather than a mark. The user chose plain text
/// over shipping either.
class MakeBadge extends StatelessWidget {
  const MakeBadge({super.key, required this.make, this.size = 26});

  final String make;
  final double size;

  /// Flip to true once `assets/makes/` exists and is declared in pubspec.
  static const hasAssets = false;

  /// Stable file name for a make: 'ב.מ.וו' → 'במוו'.
  static String assetSlug(String make) =>
      make.replaceAll(RegExp(r"[\s.\-']"), '');

  /// One or two characters that read as the marque. Latin names keep their
  /// initial; Hebrew ones take the first letter, which is what a reader
  /// scanning a list actually uses.
  static String monogram(String make) {
    final cleaned = make.replaceAll(RegExp(r'[\s.\-]'), '');
    if (cleaned.isEmpty) return '?';
    final isLatin = RegExp(r'^[A-Za-z]').hasMatch(cleaned);
    return isLatin
        ? cleaned.substring(0, 1).toUpperCase()
        : cleaned.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final monogramBadge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.tealLight,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Text(
        monogram(make),
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
          color: context.colors.tealText,
        ),
      ),
    );

    if (!hasAssets) return monogramBadge;

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/makes/${assetSlug(make)}.png',
        fit: BoxFit.contain,
        // A make with no file falls back rather than leaving a hole.
        errorBuilder: (_, __, ___) => monogramBadge,
      ),
    );
  }
}
