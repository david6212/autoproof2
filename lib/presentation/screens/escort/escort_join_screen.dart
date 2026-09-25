import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/escort_pro.dart';
import '../../providers/auth_provider.dart';
import '../../providers/escort_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/escort_verification_chip.dart';
import '../../widgets/login_required_sheet.dart';
import '../../widgets/primary_button_widget.dart';

/// The form a mechanic fills in to be listed.
///
/// **It promises nothing it cannot keep.** The licence number is submitted as
/// a claim and says so; the certificate goes to a human who will look at it;
/// and the screen states plainly that until somebody checks, the profile will
/// read "לפי הצהרת בעל המקצוע". An applicant who expects a badge on submit and
/// does not get one will conclude the app is broken — so it is said here,
/// before they type.
class EscortJoinScreen extends ConsumerStatefulWidget {
  const EscortJoinScreen({super.key});

  @override
  ConsumerState<EscortJoinScreen> createState() => _EscortJoinScreenState();
}

class _EscortJoinScreenState extends ConsumerState<EscortJoinScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _town = TextEditingController();
  final _price = TextEditingController();
  final _about = TextEditingController();
  final _years = TextEditingController();
  final _licence = TextEditingController();

  bool _insurance = false;
  bool _certificate = false;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_name, _town, _price, _about, _years, _licence]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      showLoginRequired(context, action: 'להצטרף כבעל מקצוע');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(escortRepositoryProvider).apply(
            uid: uid,
            certificateUploaded: _certificate,
            profile: EscortPro(
              id: uid,
              displayName: _name.text.trim(),
              town: _town.text.trim(),
              areas: const [],
              priceIls: int.tryParse(_price.text.trim()) ?? 0,
              about: _about.text.trim(),
              yearsExperience: int.tryParse(_years.text.trim()) ?? 0,
              claimedLicence: _licence.text.trim().isEmpty
                  ? null
                  : _licence.text.trim(),
              declaresInsurance: _insurance,
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הבקשה נשלחה. נענה תוך 14 יום.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא הצלחנו לשלוח את הבקשה. נסו שוב.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('הצטרפות כבעל מקצוע')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
            children: [
              Text(
                'קונים מחפשים מישהו שיבוא איתם לראות רכב. אתם קובעים את '
                'המחיר, והתשלום מגיע אליכם ישירות — BonnetCheck אינה גובה '
                'עמלה ואינה מעבירה כספים.',
                style: context.text.bodyMuted,
              ),
              const SizedBox(height: AppSpace.lg),

              _Field(controller: _name, label: 'שם לתצוגה', required: true),
              _Field(controller: _town, label: 'יישוב', required: true),
              _Field(
                controller: _price,
                label: 'מחיר לליווי, בשקלים',
                required: true,
                number: true,
              ),
              _Field(
                controller: _years,
                label: 'שנות ניסיון',
                number: true,
              ),
              _Field(
                controller: _about,
                label: 'מה כולל הליווי',
                lines: 3,
              ),

              const SizedBox(height: AppSpace.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('מה שאפשר לבדוק לגביכם',
                        style: AppText.subtitle),
                    const SizedBox(height: AppSpace.sm),
                    _Field(
                      controller: _licence,
                      label: 'מספר רישיון מוסך (לא חובה)',
                      number: true,
                    ),
                    Text(
                      'המספר נבדק מול מרשם המוסכים של משרד התחבורה לפני '
                      'שהוא מוצג. עד אז הוא לא מופיע בפרופיל.',
                      style: context.text.micro,
                    ),
                    const SizedBox(height: AppSpace.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _certificate,
                      onChanged: (v) => setState(() => _certificate = v),
                      title: const Text('יש לי תעודת מקצוע ואשלח אותה לבדיקה',
                          style: AppText.bodySm),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _insurance,
                      onChanged: (v) => setState(() => _insurance = v),
                      title: const Text('יש לי ביטוח אחריות מקצועית',
                          style: AppText.bodySm),
                      subtitle: Text('מוצג כהצהרה שלכם. איננו בודקים פוליסה.',
                          style: context.text.micro),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'עד שתיבדק תעודה או ימצא רישיון, הפרופיל שלכם יוצג כך:',
                      style: context.text.micro,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const EscortVerificationChip(
                      verification: EscortVerification.selfDeclared,
                      detail: 'לא הוצגה תעודה ולא נמצא רישיון מוסך',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.lg),
              const EscortLiabilityNote(),
              const SizedBox(height: AppSpace.lg),
              PrimaryButton(
                label: 'שליחה לאישור',
                loading: _sending,
                onPressed: _sending ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.required = false,
    this.number = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (!required) return null;
          return (v ?? '').trim().isEmpty ? 'שדה חובה' : null;
        },
      ),
    );
  }
}
