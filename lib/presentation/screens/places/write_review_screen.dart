import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/place.dart';
import '../../../data/models/place_review.dart';
import '../../providers/place_provider.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/garage/star_rating.dart';
import '../../widgets/primary_button_widget.dart';

/// Writing or replacing your own review of a place.
///
/// **One review per person, so this screen is always an edit of the same
/// document.** Opening it after having reviewed loads what you wrote rather
/// than offering a blank form — a second review would silently replace the
/// first, and a form that hides that is a form that loses work.
class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.placeId,
    this.vehicleId,
    this.serviceRecordIds = const [],
  });

  final String placeId;

  /// The passport this was opened from, when it was opened from one. Stored on
  /// the review so the owner's own garages list can tell which of their cars a
  /// review belongs to. It is not shown to anybody else.
  final String? vehicleId;

  final List<String> serviceRecordIds;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _text = TextEditingController();
  final _service = TextEditingController();
  final _cost = TextEditingController();
  final _model = TextEditingController();

  int _rating = 0;
  bool _saving = false;
  bool _loaded = false;
  String? _error;

  /// The car model is NOT filled from the passport, and the reason is worth
  /// keeping.
  ///
  /// The spec asked for "מהרכב שלי: טויוטה קורולה 2021", read-only. But a
  /// passport stores a nickname and a plate — not a make, a model or a year.
  /// Those live in the registry, behind the plate, and the plate is the one
  /// thing this app keeps out of everything public.
  ///
  /// Deriving the model would mean looking a private plate up and printing the
  /// answer under a public review. That is a step worth taking deliberately,
  /// not as a convenience, so the field is simply typed.

  @override
  void dispose() {
    _text.dispose();
    _service.dispose();
    _cost.dispose();
    _model.dispose();
    super.dispose();
  }

  /// Fills the form once, from the review being replaced.
  void _prefill(PlaceReview? existing) {
    if (_loaded || existing == null) return;
    _loaded = true;

    _rating = existing.rating;
    _text.text = existing.text;
    _service.text = existing.serviceType;
    if (existing.costPaid != null) _cost.text = '${existing.costPaid}';
    _model.text = existing.vehicleModel;
  }

  Future<void> _save() async {
    if (_rating == 0) {
      setState(() => _error = 'צריך לבחור דירוג');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await ref.read(placeReviewActionsProvider).save(
            placeId: widget.placeId,
            rating: _rating,
            text: _text.text,
            serviceType: _service.text,
            costPaid: int.tryParse(_cost.text.replaceAll(',', '')),
            vehicleModel: _model.text,
            vehicleId: widget.vehicleId,
            serviceRecordIds: widget.serviceRecordIds,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הביקורת נשמרה. תודה שעזרת לקהילה.')),
      );
      // Back to the place, never onward to another one. Somebody who just
      // finished writing has not asked to start again.
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'לא הצלחנו לשמור את הביקורת. נסו שוב.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('למחוק את הביקורת?'),
        content: const Text(
          'הביקורת תוסר, והדירוג שנתת ירד מהממוצע של המקום.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('ביטול')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('מחק')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(placeReviewActionsProvider).remove(widget.placeId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'לא הצלחנו למחוק את הביקורת. נסו שוב.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeAsync = ref.watch(placeByIdProvider(widget.placeId));
    final mineAsync = ref.watch(myPlaceReviewProvider(widget.placeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(mineAsync.valueOrNull == null
            ? 'כתיבת ביקורת'
            : 'עריכת הביקורת שלך'),
      ),
      body: SafeArea(
        child: placeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetry(
            message: 'לא הצלחנו לטעון את המקום',
            onRetry: () => ref.invalidate(placeByIdProvider(widget.placeId)),
          ),
          data: (place) {
            if (place == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xxl),
                  child: Text('המקום הזה כבר לא ברשימה.',
                      style: context.text.bodyMuted),
                ),
              );
            }
            if (mineAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            _prefill(mineAsync.valueOrNull);

            return ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                Text(place.name, style: AppText.h2),
                Text(place.category.label, style: context.text.bodyMuted),
                const SizedBox(height: AppSpace.lg),

                StarPicker(
                  rating: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: AppSpace.lg),

                TextField(
                  controller: _service,
                  decoration: const InputDecoration(
                    labelText: 'מה נעשה שם (לא חובה)',
                    hintText: 'טיפול 60,000 · בלמים · פוליש',
                  ),
                ),
                const SizedBox(height: AppSpace.lg),

                TextField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'כמה שילמת (לא חובה)',
                    prefixText: '₪ ',
                  ),
                ),
                const SizedBox(height: AppSpace.lg),

                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'דגם הרכב (לא חובה)',
                    hintText: 'מאזדה CX-5 2017',
                  ),
                ),
                const SizedBox(height: AppSpace.lg),

                TextField(
                  controller: _text,
                  maxLines: 4,
                  maxLength: PlaceReview.maxTextLength,
                  decoration: const InputDecoration(
                    labelText: 'מה היה שם (לא חובה)',
                    alignLabelWithHint: true,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(_error!,
                      style: AppText.bodySm.copyWith(color: colors.errorRed)),
                ],
                const SizedBox(height: AppSpace.lg),

                PrimaryButton(
                  label: 'שמור ביקורת',
                  loading: _saving,
                  onPressed: _save,
                ),
                if (mineAsync.valueOrNull != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : _delete,
                      style: TextButton.styleFrom(
                          foregroundColor: colors.errorRed),
                      child: const Text('מחק את הביקורת שלי'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                Text(
                  'הביקורת תוצג בשם הפרטי והאות הראשונה של שם המשפחה, לצד '
                  'הדירוג ופרטי הביקור שמילאתם.',
                  style: context.text.micro,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
