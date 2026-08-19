import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../app_card.dart';

/// A section the reader can fold away, for detail that matters to some buyers
/// and not to most.
///
/// The car page reached seventeen panels of equal visual weight, which handed
/// the sorting work to whoever opened it — at the moment they are least able
/// to do it. Folding is how the page keeps every fact while ranking them.
///
/// Two rules make the difference between folding and hiding:
///
/// **A collapsed section always shows a [summary].** A bare title forces the
/// reader to open it to find out whether they wanted it, which costs more
/// attention than leaving it open would have. "12 שדות" or "135 מכונים
/// מורשים" lets them decide without spending a tap.
///
/// **The choice is remembered.** Someone who opens the full spec on three
/// different listings is telling us they always want it; asking a fourth time
/// is not neutral, it is friction we chose to keep.
///
/// Deliberately not Material's `ExpansionTile`: it brings its own padding,
/// splash and divider geometry, none of which match [AppCard], and overriding
/// all three costs more than this widget does.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.summary,
    this.icon,
    this.initiallyExpanded = false,
    this.persistKey,
  });

  final String title;

  /// Shown beside the title while collapsed — what is inside, in a few words.
  final String? summary;

  final Widget child;

  /// Optional leading glyph, to match [AppSectionCard]'s header.
  final IconData? icon;

  final bool initiallyExpanded;

  /// Remembers open/closed under this key. Omit for a section whose state
  /// should not outlive the screen.
  final String? persistKey;

  /// Namespaced so a key like `spec` cannot collide with unrelated
  /// preferences.
  static String prefsKey(String persistKey) => 'section_open.$persistKey';

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  /// Whether the stored choice has been read yet.
  ///
  /// It gates the animation, and it has to do so by withholding [AnimatedSize]
  /// rather than by handing it a zero duration: changing that duration while
  /// the render object is mid-layout makes it re-dirty itself, which throws.
  /// Mounting it only once the value is settled means its first layout already
  /// has the right size, and a first layout does not animate.
  ///
  /// Without this, every screen would open with panels unfolding by themselves
  /// — the app appearing to do something, rather than showing the state the
  /// reader left behind.
  late bool _resolved = widget.persistKey == null;

  @override
  void initState() {
    super.initState();
    if (widget.persistKey != null) _restore();
  }

  Future<void> _restore() async {
    final key = widget.persistKey!;
    bool? saved;
    try {
      saved = (await SharedPreferences.getInstance())
          .getBool(CollapsibleSection.prefsKey(key));
    } catch (_) {
      // No storage on this platform — the default stands, and the section
      // still folds for the rest of the session.
    }
    if (!mounted) return;
    setState(() {
      if (saved != null) _open = saved;
      _resolved = true;
    });
  }

  Future<void> _toggle() async {
    setState(() => _open = !_open);
    final key = widget.persistKey;
    if (key == null) return;
    try {
      await (await SharedPreferences.getInstance())
          .setBool(CollapsibleSection.prefsKey(key), _open);
    } catch (_) {
      // The choice still applies to this session.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            // One node for the whole header, carrying the summary in its
            // label and owning the tap itself. Left as separate nodes a
            // screen reader announced the title, then the summary, then an
            // unlabelled button — three stops for one control, and the
            // summary read as body text rather than as part of what the
            // button opens.
            container: true,
            excludeSemantics: true,
            button: true,
            expanded: _open,
            label: _semanticsLabel,
            onTap: _toggle,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                // Brings the row to a comfortable touch height without
                // widening the card's own padding.
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: colors.teal),
                      const SizedBox(width: AppSpace.sm - 2),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: AppText.subtitle),
                          // The summary is the point of the collapsed state,
                          // so it stays visible exactly while collapsed.
                          if (!_open && widget.summary != null) ...[
                            const SizedBox(height: AppSpace.xxs),
                            Text(widget.summary!, style: context.text.caption),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      // A transform, unlike a size, is safe to settle
                      // instantly while the restored value lands.
                      duration: _resolved ? _kFold : Duration.zero,
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 22, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_resolved)
            AnimatedSize(
              duration: _kFold,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _body(),
            )
          else
            _body(),
        ],
      ),
    );
  }

  /// Title plus, while collapsed, what is inside — the same two facts a
  /// sighted reader gets from the row.
  String get _semanticsLabel {
    final summary = widget.summary;
    if (_open || summary == null) return widget.title;
    return '${widget.title}, $summary';
  }

  Widget _body() => _open
      ? Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: widget.child,
        )
      : const SizedBox(width: double.infinity);
}

/// 200ms, per the UX spec. Longer reads as the panel resisting the tap.
const _kFold = Duration(milliseconds: 200);
