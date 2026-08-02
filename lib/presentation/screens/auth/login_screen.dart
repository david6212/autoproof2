import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/legal_info.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/otov_logo.dart';
import '../../widgets/primary_button_widget.dart';
import '../../../core/theme/app_text.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _socialLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Runs a Google/Apple sign-in action, then routes home on success.
  Future<void> _social(Future<void> Function() action) async {
    setState(() => _socialLoading = true);
    try {
      await action();
      if (!mounted) return;
      ref.read(analyticsHelperProvider).loginCompleted();
      context.go('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _socialLoading = false);
      // Closing the provider's popup isn't a failure — say nothing.
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request' ||
          e.code == 'web-context-canceled' ||
          e.code == 'canceled') {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_socialError(e.code))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _socialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ההתחברות נכשלה. נסו שוב.')),
      );
    }
  }

  /// Tells the user what actually happened. "Try again" is wrong advice for a
  /// provider that isn't switched on, or for an email already used elsewhere.
  String _socialError(String code) => switch (code) {
        'operation-not-allowed' =>
          'שיטת ההתחברות הזו עדיין לא זמינה. נסו עם Google או עם מספר טלפון.',
        'account-exists-with-different-credential' =>
          'קיים כבר חשבון עם האימייל הזה. התחברו בשיטה שבה נרשמתם.',
        'network-request-failed' => 'אין חיבור לאינטרנט. בדקו ונסו שוב.',
        'too-many-requests' => 'יותר מדי ניסיונות. נסו שוב מאוחר יותר.',
        _ => 'ההתחברות נכשלה. נסו שוב.',
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    // Navigate home once verified.
    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (prev, next) {
      if (next.step == PhoneAuthStep.verified) {
        ref.read(analyticsHelperProvider).loginCompleted();
        context.go('/home');
      }
    });

    final isCodeStep = state.step == PhoneAuthStep.enterCode;

    return Scaffold(
      // No app bar: the mark is the identity here, and a title bar repeating
      // the name above the logo just pushed the form down.
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              const SizedBox(height: 12),
              // Same mark as the splash screen (shield + car + check).
              const OtovLogo(size: 132, withWordmark: true),
              const SizedBox(height: 10),
              const Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal),
              ),
              const SizedBox(height: 26),
              Text(
                isCodeStep ? 'הזן את הקוד שקיבלת' : 'התחברות',
                textAlign: TextAlign.center,
                style: AppText.h2,
              ),
              const SizedBox(height: 6),
              Text(
                isCodeStep
                    ? 'שלחנו קוד בן 6 ספרות אל ${state.phoneE164}'
                    : 'נשלח אליך קוד אימות ב-SMS',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),

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
              ] else ...[
                const SizedBox(height: 20),
                const _OrDivider(),
                const SizedBox(height: 16),
                _SocialButton(
                  label: 'המשך עם Google',
                  leading: Image.asset('assets/google_g.png',
                      width: 22, height: 22),
                  background: AppColors.white,
                  foreground: AppColors.textPrimary,
                  border: true,
                  loading: _socialLoading,
                  onPressed: () => _social(
                      () => ref.read(authRepositoryProvider).signInWithGoogle()),
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'המשך עם Apple',
                  leading: const Icon(Icons.apple,
                      color: AppColors.white, size: 22),
                  background: const Color(0xFF111111),
                  foreground: AppColors.white,
                  loading: _socialLoading,
                  onPressed: () => _social(
                      () => ref.read(authRepositoryProvider).signInWithApple()),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('גלוש בלי להתחבר ←'),
                ),
                // Only shown once the documents actually exist — a consent
                // line pointing at nothing is worse than no line.
                if (LegalInfo.isPublished) ...[
                  const SizedBox(height: 4),
                  const _ConsentNote(),
                ],
              ],
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Consent line under the sign-in options. Deliberately one plain button
/// rather than inline tappable spans: `TextSpan` needs a `TapGestureRecognizer`
/// per link, which has to be disposed, and this screen rebuilds on every
/// keystroke in the phone field.
class _ConsentNote extends StatelessWidget {
  const _ConsentNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'בהתחברות או בגלישה אתם מאשרים את',
          textAlign: TextAlign.center,
          style: AppText.micro,
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => context.push('/legal'),
          child: const Text(
            'תנאי השימוש ומדיניות הפרטיות',
            style: TextStyle(fontSize: 11.5, color: AppColors.teal),
          ),
        ),
      ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.cardBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('או', style: TextStyle(color: AppColors.textSubtle)),
        ),
        Expanded(child: Divider(color: AppColors.cardBorder)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border = false,
    this.loading = false,
  });

  final String label;
  final Widget leading;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;
  final bool border;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: border
                ? const BorderSide(color: AppColors.cardBorder)
                : BorderSide.none,
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
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
