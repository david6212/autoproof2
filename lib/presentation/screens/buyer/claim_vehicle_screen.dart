import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/ownership_transfer.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button_widget.dart';

/// The buyer's end of the handover: type the code, inherit the history.
///
/// The code is the only secret in the flow — transfers can be fetched by id
/// and never listed — so this screen is the one place it is used, and a wrong
/// code simply finds nothing.
class ClaimVehicleScreen extends ConsumerStatefulWidget {
  const ClaimVehicleScreen({super.key});

  @override
  ConsumerState<ClaimVehicleScreen> createState() => _ClaimVehicleScreenState();
}

class _ClaimVehicleScreenState extends ConsumerState<ClaimVehicleScreen> {
  final _code = TextEditingController();
  OwnershipTransfer? _found;
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final transfer = await ref.read(transferActionsProvider).lookup(_code.text);
      if (!mounted) return;
      if (transfer == null) {
        setState(() => _error = 'לא מצאנו קוד כזה. בדקו שוב מול המוכר');
      } else if (!transfer.isClaimable) {
        setState(() => _error = 'הקוד כבר נוצל או שפג תוקפו');
      } else {
        setState(() => _found = transfer);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'לא הצלחנו לבדוק את הקוד');
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _claim() async {
    final transfer = _found;
    if (transfer == null) return;

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref.read(transferActionsProvider).claim(transfer);
      if (mounted) context.pushReplacement('/vehicle/${transfer.vehicleId}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e is StateError
            ? e.message
            : 'לא הצלחנו להשלים את ההעברה. בקשו מהמוכר קוד חדש';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('קניתי רכב דרך BonnetCheck')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.lg),
          children: _found == null ? _codeStep() : _confirmStep(_found!),
        ),
      ),
    );
  }

  List<Widget> _codeStep() => [
        const Text('הזינו את קוד המסירה', style: AppText.h3),
        const SizedBox(height: AppSpace.sm),
        Text(
          'המוכר מקבל אותו באפליקציה כשהוא מסמן שהרכב נמכר. שישה תווים.',
          style: context.text.bodyMuted,
        ),
        const SizedBox(height: AppSpace.xl),
        Directionality(
          // The code is Latin. In an RTL field it would render reversed as it
          // is typed, and people correct what they see rather than what is
          // stored.
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _code,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: OwnershipTransfer.codeLength,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              _UpperCaseFormatter(),
            ],
            style: AppText.display.copyWith(fontSize: 32, letterSpacing: 8),
            decoration: const InputDecoration(hintText: '------'),
            onSubmitted: (_) => _lookup(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            _error!,
            style: AppText.bodySm.copyWith(color: context.colors.errorRed),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        PrimaryButton(
          label: 'בדוק קוד',
          loading: _working,
          onPressed: _lookup,
        ),
      ];

  List<Widget> _confirmStep(OwnershipTransfer transfer) => [
        const Text('זה הרכב שקניתם?', style: AppText.h3),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transfer.vehicleTitle.isEmpty
                    ? 'רכב ${transfer.plate}'
                    : transfer.vehicleTitle,
                style: AppText.title,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(transfer.plate, style: context.text.caption),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Icon(Icons.history,
                      size: 18, color: context.colors.textMuted),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      transfer.servicesCarried == 0
                          ? 'לרכב אין רשומות טיפול מתועדות'
                          : transfer.servicesCarried == 1
                              ? 'רשומת טיפול אחת תעבור אליכם'
                              : '${transfer.servicesCarried} רשומות טיפול '
                                  'יעברו אליכם',
                      style: AppText.bodySm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          'ההיסטוריה נשארת כפי שהיא — היא נכתבה על ידי הבעלים הקודם ואי אפשר '
          'היה לשנות אותה. מהיום תוכלו להמשיך לתעד את הרכב בעצמכם.',
          style: context.text.bodyMuted,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.lg),
          Text(
            _error!,
            style: AppText.bodySm.copyWith(color: context.colors.errorRed),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        PrimaryButton(
          label: 'קבל את הרכב',
          loading: _working,
          onPressed: _claim,
        ),
        const SizedBox(height: AppSpace.sm),
        TextButton(
          onPressed: _working ? null : () => setState(() => _found = null),
          child: const Text('זה לא הרכב שלי'),
        ),
      ];
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      TextEditingValue(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
}
