import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../providers/auth_provider.dart';
import '../providers/cars_provider.dart';
import 'login_required_sheet.dart';

/// Why someone is reporting a listing.
///
/// Fixed options rather than free text alone, so reports arrive sortable and
/// a reporter is nudged toward a fact about the listing. These mirror the
/// grounds set out in the content-removal policy.
enum ReportReason {
  misleading('פרטים שגויים או מטעים'),
  notForSale('הרכב אינו למכירה, או פורסם ללא רשות הבעלים'),
  fraud('חשד להונאה'),
  offensive('תוכן פוגעני או לא ראוי'),
  myDetails('המודעה כוללת פרטים שלי ללא הסכמתי'),
  duplicate('מודעה כפולה');

  const ReportReason(this.label);

  final String label;
}

/// What gets stored for a report: the reason, plus any detail the reporter
/// added. Kept out of the widget so the wording is testable.
String reportNote(ReportReason reason, String detail) {
  final trimmed = detail.trim();
  return trimmed.isEmpty ? reason.label : '${reason.label} — $trimmed';
}

/// Reports a whole listing.
///
/// Goes to the same `data_corrections` collection as every other "this is
/// wrong" request, so there is one queue and no new rules. Unlike a visitor
/// note, a report is never shown to anyone — that collection denies all
/// client reads — which is why the free-text box here is unrestricted where
/// note text is not.
Future<void> showReportListing(
  BuildContext context,
  WidgetRef ref, {
  required String carId,
}) async {
  if (ref.read(authStateProvider).valueOrNull == null) {
    showLoginRequired(context, action: 'לדווח על מודעה');
    return;
  }

  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _ReportSheet(carId: carId, ref: ref),
  );

  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('הדיווח נשלח. נבדוק אותו ונטפל בהתאם.'),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.carId, required this.ref});

  final String carId;
  final WidgetRef ref;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  final _detail = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return;
    setState(() => _sending = true);

    final detail = _detail.text.trim();
    await widget.ref.read(submitCorrectionProvider).call(
          kind: 'listing_report',
          carId: widget.carId,
          note: reportNote(_reason!, detail),
        );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Clears the keyboard when the detail box is focused.
      padding: EdgeInsets.only(
        left: AppSpace.lg,
        right: AppSpace.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('דיווח על המודעה', style: AppText.h3),
          const SizedBox(height: AppSpace.xs),
          Text(
            'הדיווח נשלח אלינו בלבד. הוא אינו מוצג למוכר ואינו מופיע במודעה.',
            style: context.text.caption,
          ),
          const SizedBox(height: AppSpace.lg),
          for (final r in ReportReason.values)
            RadioListTile<ReportReason>(
              value: r,
              groupValue: _reason,
              onChanged: _sending ? null : (v) => setState(() => _reason = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(r.label, style: AppText.bodySm),
            ),
          const SizedBox(height: AppSpace.sm),
          TextField(
            controller: _detail,
            enabled: !_sending,
            maxLines: 3,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'פרטים נוספים (לא חובה)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _reason == null || _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('שלח דיווח'),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
}
