import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/car_note_model.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cars_provider.dart';
import 'login_required_sheet.dart';

/// "הערות מבקרים" — crowdsourced notes from people who went to see the car,
/// visible to every future buyer.
class CarNotesSection extends ConsumerWidget {
  const CarNotesSection({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(carNotesProvider(carId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined,
                  size: 18, color: AppColors.teal),
              const SizedBox(width: 6),
              const Text('הערות מבקרים',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              notesAsync.maybeWhen(
                data: (notes) => notes.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${notes.length}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tealText)),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('מה שמבקרים קודמים ראו ברכב — עוזר לך להחליט.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          notesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => const Text('לא ניתן לטעון הערות כרגע.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            data: (notes) {
              if (notes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('עדיין אין הערות. היה הראשון לשתף מה ראית 👀',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: const BorderSide(color: AppColors.teal),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_comment_outlined, size: 19),
            label: const Text('הוסף הערה'),
            onPressed: () => _onAdd(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref, String noteId) async {
    // Reporting requires an account.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      showLoginRequired(context, action: 'לדווח על הערה');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('לדווח על ההערה?'),
        content: const Text(
            'ההערה תישלח לבדיקה אם היא פוגענית, שקרית או לא רלוונטית לרכב.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('דווח')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(reportNoteProvider).call(carId, noteId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('תודה — ההערה נשלחה לבדיקה.')),
      );
    }
  }

  void _onAdd(BuildContext context, WidgetRef ref) {
    // Adding a note requires an account — prompt guests to sign in.
    final isGuest = ref.read(authStateProvider).valueOrNull == null;
    if (isGuest) {
      ref.read(analyticsHelperProvider).guestPrompt('note');
      showLoginRequired(context, action: 'להוסיף הערה');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.teal,
                child: Text(initial,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(note.authorName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
              ),
              Text(_timeAgo(note.createdAt),
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSubtle)),
              if (isMine)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4, left: 2),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.textSubtle),
                  ),
                )
              else if (onReport != null)
                InkWell(
                  onTap: onReport,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4, left: 2),
                    child: Icon(Icons.flag_outlined,
                        size: 17, color: AppColors.textSubtle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(note.text,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.35, color: AppColors.textPrimary)),
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

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.carId});
  final String carId;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(addNoteProvider).call(widget.carId, text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שמירת ההערה נכשלה. נסה שוב.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lift the sheet above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('הוספת הערה על הרכב',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text(
              'שתפו עובדות על הרכב — מצב, פגמים, מה שראיתם. הימנעו מהאשמות אישיות במוכר.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'לדוגמה: ראיתי שריטה קלה בדלת ימין, המנוע נשמע חלק…',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white))
                : const Text('פרסם הערה'),
          ),
        ],
      ),
    );
  }
}
