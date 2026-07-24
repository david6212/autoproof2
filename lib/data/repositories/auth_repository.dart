import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/user_model.dart';

/// Wraps all Firebase Auth (phone OTP) + the users/{uid} Firestore document.
/// UI never touches FirebaseAuth or Firestore directly — only this class.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Emits the current signed-in user (or null) whenever auth state changes.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Step 1 of phone auth: send an SMS code.
  ///
  /// On success, [onCodeSent] fires with a verificationId to use in
  /// [verifyOtp]. On Android auto-retrieval, [onAutoVerified] may fire with a
  /// ready credential instead. [onFailed] fires with a Hebrew error message.
  Future<void> sendOtp({
    required String phoneE164,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) {
        onAutoVerified?.call(credential);
      },
      verificationFailed: (e) {
        onFailed(_mapAuthError(e));
      },
      codeSent: (verificationId, token) {
        onCodeSent(verificationId, token);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Step 2 of phone auth: confirm the SMS code and sign in.
  /// Ensures a users/{uid} document exists, then returns the UserModel.
  Future<UserModel> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return signInWithCredential(credential);
  }

  /// Sign in with a ready credential (used by both manual and auto flows).
  Future<UserModel> signInWithCredential(
      PhoneAuthCredential credential) async {
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;
    return _ensureUserDoc(uid: user.uid, phone: user.phoneNumber ?? '');
  }

  /// Sign in with Google (popup on web, native federated flow on mobile).
  /// Requires the Google provider to be enabled in the Firebase console.
  Future<UserModel> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final result = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    final user = result.user!;
    return _ensureUserDoc(uid: user.uid, phone: user.phoneNumber ?? '');
  }

  /// Sign in with Apple. Requires an Apple Developer account + the Apple
  /// provider configured in Firebase before it will work.
  Future<UserModel> signInWithApple() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    final result = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    final user = result.user!;
    return _ensureUserDoc(uid: user.uid, phone: user.phoneNumber ?? '');
  }

  /// Reads users/{uid}; creates a fresh buyer document if none exists.
  Future<UserModel> _ensureUserDoc({
    required String uid,
    required String phone,
  }) async {
    final ref = _users.doc(uid);
    final snap = await ref.get();

    if (snap.exists && snap.data() != null) {
      return UserModel.fromFirestore(snap.data()!, uid);
    }

    final fresh = UserModel(
      uid: uid,
      name: '',
      phone: phone,
      role: UserRole.buyer,
      verified: false,
      rating: 0.0,
      createdAt: DateTime.now(),
    );
    await ref.set(fresh.toFirestore());
    return fresh;
  }

  /// Fetch the current user's Firestore document, or null if not signed in.
  Future<UserModel?> fetchCurrentUserModel() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final snap = await _users.doc(u.uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromFirestore(snap.data()!, u.uid);
  }

  /// Marks the current user as a verified private seller and saves their name.
  /// Throws if no user is signed in.
  Future<void> markVerifiedSeller({required String name}) async {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('לא ניתן לאמת ללא התחברות.');
    }
    await _users.doc(u.uid).set(
      {
        'name': name,
        'role': UserRole.seller.name,
        'verified': true,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> signOut() => _auth.signOut();

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'מספר הטלפון שגוי. בדוק ונסה שוב.';
      case 'too-many-requests':
        return 'יותר מדי ניסיונות. נסה שוב מאוחר יותר.';
      case 'invalid-verification-code':
        return 'הקוד שגוי. בדוק את הספרות ונסה שוב.';
      case 'session-expired':
        return 'הקוד פג תוקף. שלח קוד חדש.';
      default:
        return 'האימות נכשל. נסה שוב.';
    }
  }
}
