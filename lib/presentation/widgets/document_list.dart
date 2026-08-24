import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../data/models/vehicle_document.dart';
import 'app_card.dart';
import 'photo_viewer.dart';

/// The owner's attached files, each with its own sharing switch.
///
/// The switch is per document and not per vehicle because the documents are
/// not alike: an inspection report is exactly what a buyer should see, and a
/// vehicle licence has the owner's ID number and home address on it. One
/// global "share my documents" toggle would make the safe choice and the
/// useful choice the same choice, and people would pick useful.
class DocumentList extends StatelessWidget {
  const DocumentList({
    super.key,
    required this.documents,
    this.onToggleShare,
    this.onDelete,
    this.readOnly = false,
  });

  final List<VehicleDocument> documents;
  final void Function(VehicleDocument doc, bool shared)? onToggleShare;
  final void Function(VehicleDocument doc)? onDelete;

  /// The buyer's view: open a document, nothing else.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in documents)
          _DocumentRow(
            document: d,
            onToggleShare: readOnly ? null : onToggleShare,
            onDelete: readOnly ? null : onDelete,
          ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    this.onToggleShare,
    this.onDelete,
  });

  final VehicleDocument document;
  final void Function(VehicleDocument doc, bool shared)? onToggleShare;
  final void Function(VehicleDocument doc)? onDelete;

  Future<void> _confirmShare(BuildContext context) async {
    // Only for the kinds that carry an ID number or an address. Warning on
    // every document would train people to tap through the warning.
    if (!document.type.carriesPersonalData) {
      onToggleShare?.call(document, true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('להציג את המסמך לקונים?'),
        content: Text(
          '${document.type.label} כולל לרוב פרטים אישיים — מספר תעודת זהות, '
          'כתובת או מספר פוליסה. כל מי שיצפה במודעה יוכל לראות אותם.\n\n'
          'ביטול השיתוף מסתיר את המסמך באפליקציה, אבל מי שכבר שמר את הקישור '
          'עדיין יוכל לפתוח אותו. רק מחיקת הקובץ מבטלת גישה.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('הצג בכל זאת'),
          ),
        ],
      ),
    );
    if (ok == true) onToggleShare?.call(document, true);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('למחוק את המסמך?'),
        content: const Text(
          'הקובץ יימחק לצמיתות. זו גם הדרך היחידה לבטל גישה למי שכבר קיבל '
          'את הקישור אליו.',
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete?.call(document);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shared = document.isSharedWithBuyers;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  document.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 20,
                  color: colors.teal,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(document.displayTitle, style: AppText.subtitle),
                      Text(
                        [
                          document.type.label,
                          if (document.sizeLabel.isNotEmpty) document.sizeLabel,
                        ].join(' · '),
                        style: context.text.caption,
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'מחק',
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                if (!document.isPdf)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_full, size: 18),
                    label: const Text('פתח'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PhotoViewer(
                          photos: [document.fileUrl],
                          initialIndex: 0,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                if (onToggleShare != null) ...[
                  Text(
                    shared ? 'מוצג לקונים' : 'פרטי',
                    style: AppText.bodySm.copyWith(
                      color: shared ? colors.tealText : colors.textMuted,
                    ),
                  ),
                  Switch(
                    value: shared,
                    onChanged: (v) => v
                        ? _confirmShare(context)
                        : onToggleShare!(document, false),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
