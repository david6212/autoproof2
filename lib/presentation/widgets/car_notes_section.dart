import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/car_note_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cars_provider.dart';
import '../../core/theme/app_text.dart';
import 'app_card.dart';
import 'login_required_sheet.dart';

/// "ממצאי מבקרים" — what people who went to inspect this car found,
/// visible to every future buyer.
///
/// Every note is a set of ticks from a closed bank of observations about the
/// vehicle. There is no free-text field and no way to describe the seller:
/// both existed here until 24/08/2026 and both were removed — the text because
/// it was queued for a review nobody performed, and the seller reporting
/// because a crowd verdict on a named person is the one thing a listing site
/// should not host.
class CarNotesSection extends ConsumerWidget {
  const CarNotesSection({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(carNotesProvider(carId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return AppSectionCard(
      icon: Icons.rate_review_outlined,
      title: 'ממצאי מבקרים',
      source: DataSource.community,
      subtitle: 'מה שמבקרים קודמים מצאו בבדיקה — עוזר לך להחליט מה לבדוק.',
      trailing: notesAsync.maybeWhen(
        data: (notes) => notes.isEmpty
            ? const SizedBox.shrink()
            : AppCountBadge(count: notes.length),
        orElse: () => const SizedBox.shrink(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          notesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => _InlineRetry(
              message: 'לא ניתן לטעון הערות כרגע.',
              onRetry: () => ref.invalidate(carNotesProvider(carId)),
            ),
            data: (notes) {
              if (notes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                      'עדיין אין ממצאים. היה הראשון לשתף מה מצאת בבדיקה 👀',
                      style: context.text.bodySmMuted),
                );
              }
              return Column(
                children: [
                  for (final note in notes)
                    _NoteTile(
                      note: note,
                      isMine: note.authorUid == myUid,
                      onDelete: () => ref
                          .read(deleteNoteProvider)
                          .call(carId, note.id),
                      onReport: note.authorUid == myUid
                          ? null
                          : () => _report(context, ref, note.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Styling comes from outlinedButtonTheme; only the width is local.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_comment_outlined, size: 19),
              label: const Text('הוסף ממצא מבדיקה'),
              onPressed: () => _onAdd(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref, String noteId) async {
    // Reporting requires an account.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      showLoginRequired(context, action: 'לדווח על ממצא');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('לדווח על הממצא?'),
        content: const Text(
            'הדיווח יישלח לבדיקה אם הממצאים שסומנו אינם נכונים או אינם שייכים לרכב הזה.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.colors.tealFill),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('דווח')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(reportNoteProvider).call(carId, noteId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('תודה — הדיווח נשלח לבדיקה.')),
      );
    }
  }

  void _onAdd(BuildContext context, WidgetRef ref) {
    // Adding a note requires an account — prompt guests to sign in.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      ref.read(analyticsHelperProvider).guestPrompt('note');
      showLoginRequired(context, action: 'להוסיף ממצא');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddNoteSheet(carId: carId),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.isMine,
    required this.onDelete,
    this.onReport,
  });

  final CarNote note;
  final bool isMine;
  final VoidCallback onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final trimmed = note.authorName.trim();
    final initial = trimmed.isNotEmpty ? trimmed.substring(0, 1) : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: context.colors.tealFill,
                child: Text(initial,
                    style: TextStyle(
                        color: context.colors.onBrand,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(note.authorName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: context.colors.textPrimary)),
              ),
              Text(_timeAgo(note.createdAt),
                  style: context.text.micro),
              if (isMine)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4, left: 2),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: context.colors.textSubtle),
                  ),
                )
              else if (onReport != null)
                InkWell(
                  onTap: onReport,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4, left: 2),
                    child: Icon(Icons.flag_outlined,
                        size: 17, color: context.colors.textSubtle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Only the fixed observations are ever rendered.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in note.tags) _TagChip(tag: tag),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact Hebrew relative time ("לפני 3 שעות").
  static String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'עכשיו';
    if (d.inMinutes < 60) return 'לפני ${d.inMinutes} דק׳';
    if (d.inHours < 24) return 'לפני ${d.inHours} שע׳';
    if (d.inDays < 30) return 'לפני ${d.inDays} ימים';
    if (d.inDays < 365) return 'לפני ${(d.inDays / 30).floor()} חודשים';
    return 'לפני ${(d.inDays / 365).floor()} שנים';
  }
}

/// One ticked observation. Positive ones read green, cautionary ones amber —
/// no red, because nothing on the list is an accusation.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final NoteTag tag;

  @override
  Widget build(BuildContext context) {
    final positive = tag.isPositive;
    final bg = positive ? context.colors.tealLight : context.colors.warnBg;
    final fg = positive ? context.colors.tealText2 : context.colors.warnText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(positive ? Icons.check : Icons.info_outline, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(tag.label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.carId});
  final String carId;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _tags = <NoteTag>{};
  bool _saving = false;

  Future<void> _submit() async {
    if (_tags.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(addNoteProvider).call(widget.carId, _tags.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שמירת הממצאים נכשלה. נסה שוב.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('מה מצאתם בבדיקה?', style: AppText.title),
                const SizedBox(height: 4),
                Text(
                  'סמנו כל מה שראיתם. אין כאן שדה חופשי בכוונה — רשימה סגורה '
                  'מתארת את הרכב, ולא את מי שמוכר אותו.',
                  style: context.text.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final group in NoteGroup.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpace.md, bottom: AppSpace.sm),
                    child: Text(
                      group.label,
                      style: AppText.subtitle
                          .copyWith(color: context.colors.textMuted),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in NoteTagX.inGroup(group))
                        _PickChip(
                          tag: tag,
                          selected: _tags.contains(tag),
                          onSelected: (on) => setState(
                              () => on ? _tags.add(tag) : _tags.remove(tag)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
              ],
            ),
          ),
          // Sits outside the scroll view: with twenty-seven options the button
          // would otherwise be somewhere below the fold, and a person who has
          // ticked what they came to tick should not have to hunt for it.
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tags.isEmpty
                      ? 'סמנו לפחות דבר אחד'
                      : 'סומנו ${_tags.length} ממצאים',
                  style: context.text.caption,
                ),
                const SizedBox(height: AppSpace.sm),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.tealFill,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: (_saving || _tags.isEmpty) ? null : _submit,
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.colors.onBrand))
                      : const Text('שלח דיווח'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One option in the bank. A [FilterChip] with the label allowed to wrap:
/// "בלאי בהגה ובדוושות שאינו תואם לקילומטראז'" does not fit a phone in one
/// line, and a chip that ellipsises hides the half that says what it means.
class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.tag,
    required this.selected,
    required this.onSelected,
  });

  final NoteTag tag;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 64,
      ),
      child: FilterChip(
        label: Text(tag.label),
        selected: selected,
        showCheckmark: true,
        checkmarkColor: colors.onBrand,
        selectedColor: colors.teal,
        backgroundColor: colors.background,
        side: BorderSide(
            color: selected ? colors.teal : colors.cardBorder),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? colors.onBrand : colors.textMuted,
        ),
        onSelected: onSelected,
      ),
    );
  }
}

/// A one-line failure with a retry beside it, for a section nested inside a
/// card. The full [ErrorRetry] block is right for a whole screen and far too
/// heavy for a footnote.
class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(child: Text(message, style: context.text.bodySmMuted)),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('נסו שוב'),
          ),
        ],
      );
}
