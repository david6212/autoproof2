import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/gov_data_model.dart';
import '../../providers/seller_verification_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/step_progress_widget.dart';
import '../../../core/theme/app_text.dart';

class VerifyPlateScreen extends ConsumerStatefulWidget {
  const VerifyPlateScreen({super.key});

  @override
  ConsumerState<VerifyPlateScreen> createState() => _VerifyPlateScreenState();
}

class _VerifyPlateScreenState extends ConsumerState<VerifyPlateScreen> {
  final _plateController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _plateController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    ref
        .read(sellerVerificationControllerProvider.notifier)
        .verifyPlate(_plateController.text.trim());
  }

  void _continue() {
    final notifier = ref.read(sellerVerificationControllerProvider.notifier);
    notifier.setName(_nameController.text.trim());
    context.go('/verify/success');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerVerificationControllerProvider);
    final car = state.carData;
    final nameOk = _nameController.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('אימות מוכר')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(current: 2),
              const SizedBox(height: AppSpace.xl),
              const Text('אימות בעלות', style: AppText.h3),
              const SizedBox(height: AppSpace.xs + 2),
              Text(
                'הזן את מספר הרישוי של הרכב שברשותך',
                style: context.text.bodySmMuted,
              ),
              const SizedBox(height: AppSpace.lg),

              TextField(
                controller: _plateController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                enabled: car == null,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: const InputDecoration(
                  labelText: 'מספר רישוי',
                  hintText: '12345678',
                  hintTextDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 15, color: context.colors.textSubtle),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.idOnlyNote,
                    style:
                        TextStyle(fontSize: 12.5, color: context.colors.textSubtle),
                  ),
                ],
              ),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: state.error!),
              ],

              const SizedBox(height: 20),

              if (car == null)
                PrimaryButton(
                  label: state.loading
                      ? AppStrings.verifyingWithGov
                      : 'אמת מול משרד התחבורה',
                  loading: state.loading,
                  onPressed: _verify,
                )
              else ...[
                _CarConfirmCard(car: car),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'שם מלא',
                    hintText: 'ישראל ישראלי',
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: AppStrings.continueBtn,
                  onPressed: nameOk ? _continue : null,
                ),
                TextButton(
                  onPressed: () => ref
                      .read(sellerVerificationControllerProvider.notifier)
                      .reset(),
                  child: const Text('הזן מספר אחר'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CarConfirmCard extends StatelessWidget {
  const _CarConfirmCard({required this.car});
  final GovData car;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      color: context.colors.tealLight,
      borderColor: context.colors.teal,
      child: Row(
        children: [
          Icon(Icons.check_circle, color: context.colors.tealText, size: 26),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(car.title,
                    style: AppText.title
                        .copyWith(color: context.colors.tealText)),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  '${car.year} · ${car.ownershipType}',
                  style: AppText.bodySm
                      .copyWith(color: context.colors.tealText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    // A banner, not a card — it is a message about what just happened, so it
    // keeps the tint and drops the border rather than posing as content.
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md + 2, vertical: AppSpace.md),
      decoration: BoxDecoration(
        color: context.colors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.colors.errorRed, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              message,
              style: AppText.bodySm.copyWith(color: context.colors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
