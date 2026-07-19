import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/plate_formatter.dart';
import '../../providers/gov_api_provider.dart';
import '../../widgets/gov_data_card_widget.dart';
import '../../widgets/primary_button_widget.dart';

class VehicleHistoryScreen extends ConsumerStatefulWidget {
  const VehicleHistoryScreen({super.key, required this.carId});

  /// The plate to pre-fill. In Phase 3 this may be typed by the user; later
  /// it is auto-filled from the current car.
  final String carId;

  @override
  ConsumerState<VehicleHistoryScreen> createState() =>
      _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends ConsumerState<VehicleHistoryScreen> {
  late final TextEditingController _plateController;

  @override
  void initState() {
    super.initState();
    // Pre-fill only if the incoming id is plate-like (digits).
    final prefill = PlateFormatter.digitsOnly(widget.carId);
    _plateController = TextEditingController(text: prefill);
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    ref
        .read(govLookupControllerProvider.notifier)
        .search(_plateController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(govLookupControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('היסטוריית רכב')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _plateController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
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
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'בדוק',
                loading: result.isLoading,
                onPressed: _search,
              ),
              const SizedBox(height: 20),
              result.when(
                data: (data) => data == null
                    ? const _Hint()
                    : GovDataCard(data: data),
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => _ErrorBox(
                  message: err.toString(),
                  onRetry: _search,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.directions_car_outlined,
              size: 56, color: AppColors.textSubtle),
          SizedBox(height: 12),
          Text(
            'הזן מספר רישוי לקבלת נתונים רשמיים',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.errorRed),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
