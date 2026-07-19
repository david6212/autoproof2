import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/seller_verification_provider.dart';
import '../../widgets/primary_button_widget.dart';
import '../../widgets/step_progress_widget.dart';

class VerifySuccessScreen extends ConsumerStatefulWidget {
  const VerifySuccessScreen({super.key});

  @override
  ConsumerState<VerifySuccessScreen> createState() =>
      _VerifySuccessScreenState();
}

class _VerifySuccessScreenState extends ConsumerState<VerifySuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Persist verification as soon as we land here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sellerVerificationControllerProvider.notifier).submit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sellerVerificationControllerProvider);
    final car = state.carData;

    return Scaffold(
      appBar: AppBar(title: const Text('אימות מוכר')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(current: 3),
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: AppColors.tealLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    state.error != null
                        ? Icons.error_outline
                        : Icons.verified_user,
                    size: 60,
                    color: state.error != null
                        ? AppColors.errorRed
                        : AppColors.teal,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (state.loading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                const Text(
                  'שומר את האימות...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ] else if (state.error != null) ...[
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.errorRed,
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: AppStrings.retry,
                  onPressed: () => ref
                      .read(sellerVerificationControllerProvider.notifier)
                      .submit(),
                ),
              ] else ...[
                const Text(
                  AppStrings.verifiedSuccess,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  AppStrings.verifiedAsPrivate,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
                if (car != null) ...[
                  const SizedBox(height: 24),
                  _CarPreview(title: car.title, sub: '${car.year} · ${car.ownershipType}'),
                ],
                const Spacer(),
                PrimaryButton(
                  label: AppStrings.continueToListing,
                  onPressed: () => context.go('/seller/create'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CarPreview extends StatelessWidget {
  const _CarPreview({required this.title, required this.sub});
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
