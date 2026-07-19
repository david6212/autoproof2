import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    // Navigate home once verified.
    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (prev, next) {
      if (next.step == PhoneAuthStep.verified) {
        context.go('/home');
      }
    });

    final isCodeStep = state.step == PhoneAuthStep.enterCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Icon(
                isCodeStep ? Icons.sms_outlined : Icons.phone_iphone,
                size: 56,
                color: AppColors.teal,
              ),
              const SizedBox(height: 24),
              Text(
                isCodeStep ? 'הזן את הקוד שקיבלת' : 'התחברות',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCodeStep
                    ? 'שלחנו קוד בן 6 ספרות אל ${state.phoneE164}'
                    : 'נשלח אליך קוד אימות ב-SMS',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 28),

              if (!isCodeStep)
                _PhoneField(controller: _phoneController)
              else
                _CodeField(controller: _codeController),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: state.error!),
              ],

              const SizedBox(height: 24),
              PrimaryButton(
                label: isCodeStep ? 'אמת קוד' : AppStrings.sendCode,
                loading: state.loading,
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  if (isCodeStep) {
                    controller.verifyCode(_codeController.text.trim());
                  } else {
                    controller.sendCode(_phoneController.text.trim());
                  }
                },
              ),

              if (isCodeStep) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.loading
                      ? null
                      : () {
                          _codeController.clear();
                          controller.reset();
                        },
                  child: const Text('שנה מספר טלפון'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: const InputDecoration(
        labelText: 'מספר טלפון',
        hintText: '050-1234567',
        hintTextDirection: TextDirection.ltr,
        prefixText: '+972 ',
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLength: 6,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 12,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: const InputDecoration(
        counterText: '',
        hintText: '••••••',
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
