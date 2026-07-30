import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button_widget.dart';

/// Attaches a phone number to an account that signed in with Google or Apple.
///
/// Publishing a listing requires a number: it is the one step that makes a
/// throwaway account cost something, and it gives a real contact route if a
/// buyer later disputes a listing.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _verificationId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Israeli mobile input ("0501234567") to the E.164 form Firebase expects.
  String? _toE164(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('972')) return '+$digits';
    if (digits.startsWith('0') && digits.length == 10) {
      return '+972${digits.substring(1)}';
    }
    return null;
  }

  Future<void> _sendCode() async {
    final e164 = _toE164(_phoneController.text);
    if (e164 == null) {
      setState(() => _error = 'מספר לא תקין. לדוגמה: 0501234567');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(authRepositoryProvider).sendOtp(
          phoneE164: e164,
          onCodeSent: (id, _) {
            if (!mounted) return;
            setState(() {
              _verificationId = id;
              _busy = false;
            });
          },
          onFailed: (message) {
            if (!mounted) return;
            setState(() {
              _error = message;
              _busy = false;
            });
          },
        );
  }

  Future<void> _confirm() async {
    final id = _verificationId;
    if (id == null || _codeController.text.trim().length < 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).linkPhone(
            verificationId: id,
            smsCode: _codeController.text.trim(),
          );
      ref.invalidate(currentUserModelProvider);
      if (mounted) context.go('/seller/create');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _verificationId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('אימות מספר טלפון')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phone_iphone,
                  size: 56, color: AppColors.teal),
              const SizedBox(height: 16),
              const Text(
                'כדי לפרסם מודעה צריך מספר טלפון מאומת',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'המספר משמש לאימות בלבד ולא יוצג במודעה. הוא מקשה על פתיחת '
                'חשבונות מזויפים ומגן גם עליך וגם על הקונים.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phoneController,
                enabled: !sent,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'מספר טלפון',
                  hintText: '0501234567',
                  hintTextDirection: TextDirection.ltr,
                ),
              ),
              if (sent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'קוד מה-SMS',
                    hintText: '123456',
                    hintTextDirection: TextDirection.ltr,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.errorRed, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: sent ? 'אמת והמשך' : 'שלח קוד',
                loading: _busy,
                onPressed: _busy ? null : (sent ? _confirm : _sendCode),
              ),
              if (sent) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _verificationId = null;
                            _codeController.clear();
                          }),
                  child: const Text('שינוי מספר'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
