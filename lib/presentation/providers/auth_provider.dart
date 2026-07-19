import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Single shared AuthRepository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Emits the FirebaseAuth user (or null) as auth state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The current signed-in user's Firestore document (null if not signed in).
final currentUserModelProvider = FutureProvider<UserModel?>((ref) async {
  // Re-fetch whenever auth state changes.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).fetchCurrentUserModel();
});

/// Steps of the phone OTP flow.
enum PhoneAuthStep { enterPhone, enterCode, verified }

/// State for the login screen's phone OTP flow.
class PhoneAuthState {
  final PhoneAuthStep step;
  final bool loading;
  final String? verificationId;
  final int? resendToken;
  final String? phoneE164;
  final String? error;

  const PhoneAuthState({
    this.step = PhoneAuthStep.enterPhone,
    this.loading = false,
    this.verificationId,
    this.resendToken,
    this.phoneE164,
    this.error,
  });

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    bool? loading,
    String? verificationId,
    int? resendToken,
    String? phoneE164,
    String? error,
    bool clearError = false,
  }) {
    return PhoneAuthState(
      step: step ?? this.step,
      loading: loading ?? this.loading,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      phoneE164: phoneE164 ?? this.phoneE164,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Normalize an Israeli phone number to E.164 (+972...).
  /// Accepts "0501234567", "501234567", "+972501234567".
  static String toE164(String raw) {
    var d = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (d.startsWith('+')) return d;
    if (d.startsWith('972')) return '+$d';
    if (d.startsWith('0')) d = d.substring(1);
    return '+972$d';
  }

  Future<void> sendCode(String rawPhone) async {
    final phone = toE164(rawPhone);
    state = state.copyWith(loading: true, clearError: true, phoneE164: phone);

    await _repo.sendOtp(
      phoneE164: phone,
      resendToken: state.resendToken,
      onCodeSent: (verificationId, token) {
        state = state.copyWith(
          loading: false,
          step: PhoneAuthStep.enterCode,
          verificationId: verificationId,
          resendToken: token,
        );
      },
      onAutoVerified: (credential) async {
        try {
          await _repo.signInWithCredential(credential);
          state = state.copyWith(
              loading: false, step: PhoneAuthStep.verified);
        } catch (_) {
          // Fall through — user can still type the code manually.
        }
      },
      onFailed: (message) {
        state = state.copyWith(loading: false, error: message);
      },
    );
  }

  Future<void> verifyCode(String smsCode) async {
    final vid = state.verificationId;
    if (vid == null) {
      state = state.copyWith(error: 'שלח קוד תחילה.');
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.verifyOtp(verificationId: vid, smsCode: smsCode);
      state = state.copyWith(loading: false, step: PhoneAuthStep.verified);
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'invalid-verification-code'
          ? 'הקוד שגוי. בדוק את הספרות ונסה שוב.'
          : 'האימות נכשל. נסה שוב.';
      state = state.copyWith(loading: false, error: msg);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'האימות נכשל. נסה שוב.');
    }
  }

  void reset() => state = const PhoneAuthState();
}

final phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(
  PhoneAuthController.new,
);
