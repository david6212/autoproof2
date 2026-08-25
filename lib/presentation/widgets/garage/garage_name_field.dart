import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/place.dart';
import '../../providers/place_provider.dart';

/// The garage field on the service form, with suggestions from the directory.
///
/// **The directory starts empty, and the field is honest about it.** There is
/// no public register of repair garages to seed from — the Ministry publishes
/// inspection centres, and those already live elsewhere in this app — so for
/// a while the only result will be "add it". A field that showed a spinner and
/// then nothing, with no way forward, would read as broken.
///
/// Picking a suggestion is what turns the typed name into a link: it hands
/// back a [Place] id, and the service record stores it. Typing a name by hand
/// stays perfectly valid and yields null — most people will, and a record
/// without a garage page is still a record.
class GarageNameField extends ConsumerStatefulWidget {
  const GarageNameField({
    super.key,
    required this.controller,
    required this.onPlaceIdSelected,
    this.onAddPlace,
    this.label = 'שם המוסך (לא חובה)',
  });

  final TextEditingController controller;

  /// The chosen place's id, or null the moment the text stops matching what
  /// was chosen. A stale id on a renamed garage would link the record to the
  /// wrong page.
  final ValueChanged<String?> onPlaceIdSelected;

  /// Opens the "add a place" flow with the typed name. Omitted until that
  /// screen exists — and while it is omitted the row is not drawn, rather than
  /// drawn and dead.
  final void Function(String typedName)? onAddPlace;

  final String label;

  @override
  ConsumerState<GarageNameField> createState() => _GarageNameFieldState();
}

class _GarageNameFieldState extends ConsumerState<GarageNameField> {
  final _focus = FocusNode();

  /// What the suggestions are actually being fetched for. Trails the field by
  /// [_settle] so a fast typist does not spend one query per character.
  String _query = '';
  Timer? _debounce;

  /// The name that was picked from the list, so an edit afterwards can clear
  /// the id it came with.
  String? _pickedName;

  static const _settle = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTyped);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTyped);
    _focus.dispose();
    super.dispose();
  }

  void _onTyped() {
    final text = widget.controller.text;

    // The moment the text diverges from the chosen place, the link is stale.
    if (_pickedName != null && text.trim() != _pickedName) {
      _pickedName = null;
      widget.onPlaceIdSelected(null);
    }

    _debounce?.cancel();
    _debounce = Timer(_settle, () {
      if (!mounted) return;
      setState(() => _query = text.trim());
    });
  }

  void _pick(Place place) {
    _pickedName = place.name;
    widget.controller
      ..text = place.name
      ..selection = TextSelection.collapsed(offset: place.name.length);
    widget.onPlaceIdSelected(place.id);
    _focus.unfocus();
    setState(() => _query = place.name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Nothing is fetched, and nothing is drawn, until the field is being used
    // and there is enough typed to narrow anything down.
    final open = _focus.hasFocus && _query.length >= 2 && _pickedName == null;
    final results =
        open ? ref.watch(placeSearchProvider(_query)) : const AsyncValue.data(<Place>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: _pickedName != null
                ? Icon(Icons.link, size: 18, color: colors.teal)
                : null,
          ),
        ),
        if (open)
          results.when(
            loading: () => const _Row(child: _Spinner()),
            // A failed lookup must not block the form: the name is free text
            // and the record saves without a link.
            error: (_, __) => const SizedBox.shrink(),
            data: (places) => Container(
              margin: const EdgeInsets.only(top: AppSpace.xs),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Column(
                children: [
                  for (final p in places)
                    _Suggestion(place: p, onTap: () => _pick(p)),
                  if (widget.onAddPlace != null)
                    _AddRow(
                      name: widget.controller.text.trim(),
                      isOnly: places.isEmpty,
                      onTap: () => widget.onAddPlace!(
                          widget.controller.text.trim()),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Row(
          children: [
            Icon(Icons.place_outlined, size: 17, color: colors.teal),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm),
                  Text(
                    [
                      place.category.label,
                      if (place.city.isNotEmpty) place.city,
                    ].join(' · '),
                    style: context.text.micro,
                  ),
                ],
              ),
            ),
            // The average is withheld below three reviews — two opinions
            // rendered as a score read as a verdict on somebody's business.
            //
            // The star is an icon and not the character ★. Heebo does not
            // carry it, and Flutter's web engine answers a missing glyph by
            // downloading a Noto fallback from Google at runtime — which is
            // the request the bundled fonts exist to prevent. Every star in
            // this feature has to be drawn the same way.
            if (place.hasEnoughRatings) ...[
              Text(place.ratingAvg.toStringAsFixed(1),
                  style: context.text.micro),
              const SizedBox(width: 2),
              Icon(Icons.star_rounded, size: 13, color: colors.warnText),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.name,
    required this.isOnly,
    required this.onTap,
  });

  final String name;

  /// True when nothing matched, which for a while will be most of the time.
  final bool isOnly;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          border: isOnly
              ? null
              : Border(top: BorderSide(color: colors.cardBorder)),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 17, color: colors.tealText2),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                isOnly
                    ? 'לא מצאנו את "$name". להוסיף אותו לרשימה?'
                    : 'הוסף את "$name" לרשימה',
                style: AppText.bodySm.copyWith(color: colors.tealText2),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: AppSpace.xs),
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.colors.cardBorder),
        ),
        child: child,
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}
