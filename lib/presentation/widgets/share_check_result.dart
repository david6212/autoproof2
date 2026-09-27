import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gov_data_model.dart';
import 'app_card.dart';

final _kmFmt = NumberFormat('#,###', 'en');

/// Sharing what the registry said about a car.
///
/// **The message outlives the screen it came from.** A WhatsApp forward has no
/// disclaimer around it, no source banner above it and no way to ask where the
/// numbers came from — so the text carries its own: what the registry holds,
/// when it was read, that it is an open government dataset, and that it is not
/// an inspection. The same rule the listing share already follows.
///
/// **The plate does not go out unless the sender says so.** It is the one
/// field that identifies a car and its keeper, and this app has kept it out of
/// public documents, out of analytics and out of the cache. A person may of
/// course send their own message with the number in it — what this refuses to
/// do is make that the default.
String checkShareText(
  GovData data, {
  String? plate,
  DateTime? checkedAt,
}) {
  final name = data.commercialName.isNotEmpty ? data.commercialName : data.model;
  final title = '${data.make} $name'.trim();
  final when = checkedAt ?? DateTime.now();

  final lines = <String>[
    'בדיקת רכב מול מרשם הרכב',
    '',
    [title, if (data.year > 0) '${data.year}'].join(' · '),
    if (plate != null && plate.trim().isNotEmpty) 'מספר רישוי: ${plate.trim()}',
    if (data.ownershipType.isNotEmpty) 'בעלות: ${data.ownershipType}',
    if (data.lastTestDate != null)
      'טסט אחרון: ${DateFormatter.format(data.lastTestDate!)}'
          '${data.lastTestKm == null ? '' : ' · ${_kmFmt.format(data.lastTestKm)} ק"מ'}',
    if (data.licenseExpiry != null)
      'רישיון בתוקף עד: ${DateFormatter.format(data.licenseExpiry!)}',
  ];

  // Findings, and only the ones the datasets actually answered. "No open
  // recalls" when the recall list never replied is a claim about a check that
  // did not run — the model records the difference and the message keeps it.
  if (data.offRoad) {
    lines.add('שימו לב: הרכב רשום כמבוטל או שירד מהכביש.');
  }
  if (data.answered(GovDataset.recalls) && data.recalls.isNotEmpty) {
    lines.add(data.recalls.length == 1
        ? 'קריאת שירות פתוחה אחת של היצרן'
        : '${data.recalls.length} קריאות שירות פתוחות של היצרן');
  }
  if (data.colorChanged) lines.add('רשום שינוי צבע');

  lines.addAll([
    '',
    'נבדק ב-${DateFormatter.format(when)} · המידע ממאגר ממשלתי פתוח '
        '(data.gov.il), עשוי להיות חסר או לא מעודכן, ואינו אישור רשמי ואינו '
        'בדיקה של הרכב עצמו.',
    AppStrings.siteUrl,
  ]);

  return lines.join('\n');
}

/// The share control under a check result.
///
/// A switch rather than two buttons: including the plate is a decision, and a
/// decision with a default is easier to make than a fork with two equal doors.
class ShareCheckResult extends StatefulWidget {
  const ShareCheckResult({
    super.key,
    required this.data,
    required this.plate,
    this.onShared,
  });

  final GovData data;
  final String plate;

  /// Called after the sheet was opened — for counting that a share happened,
  /// never what was in it.
  final VoidCallback? onShared;

  @override
  State<ShareCheckResult> createState() => _ShareCheckResultState();
}

class _ShareCheckResultState extends State<ShareCheckResult> {
  /// Off by default, deliberately. See [checkShareText].
  bool _includePlate = false;

  Future<void> _share() async {
    final box = context.findRenderObject() as RenderBox?;
    final text = checkShareText(
      widget.data,
      plate: _includePlate ? widget.plate : null,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      widget.onShared?.call();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא הצלחנו לפתוח את תפריט השיתוף.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('שלחו את הממצאים', style: AppText.subtitle),
          const SizedBox(height: AppSpace.xxs),
          Text(
            'למי שקונה איתכם, או למי שמבין ברכבים. ההודעה כוללת את מה '
            'שהמרשם רשם ואת המקור.',
            style: context.text.micro,
          ),
          const SizedBox(height: AppSpace.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _includePlate,
            onChanged: (v) => setState(() => _includePlate = v),
            title: const Text('לצרף את מספר הרישוי', style: AppText.bodySm),
            subtitle: Text(
              'כבוי כברירת מחדל. מספר רישוי מזהה רכב ואת בעליו, והודעה '
              'שנשלחה ממשיכה הלאה בלי שליטה.',
              style: context.text.micro,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.tealFill,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('שיתוף'),
            onPressed: _share,
          ),
        ],
      ),
    );
  }
}
