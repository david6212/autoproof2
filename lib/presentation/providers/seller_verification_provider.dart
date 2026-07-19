import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gov_data_model.dart';
import '../../data/sources/remote/gov_api_service.dart';
import 'auth_provider.dart';
import 'gov_api_provider.dart';

/// Holds the seller-verification flow state across the 3 verify screens.
class SellerVerificationState {
  final GovData? carData;
  final String name;
  final bool loading; // gov lookup OR firestore save in progress
  final String? error;
  final bool saved;

  const SellerVerificationState({
    this.carData,
    this.name = '',
    this.loading = false,
    this.error,
    this.saved = false,
  });

  SellerVerificationState copyWith({
    GovData? carData,
    String? name,
    bool? loading,
    String? error,
    bool? saved,
    bool clearError = false,
    bool clearCar = false,
  }) {
    return SellerVerificationState(
      carData: clearCar ? null : (carData ?? this.carData),
      name: name ?? this.name,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      saved: saved ?? this.saved,
    );
  }
}

class SellerVerificationController extends Notifier<SellerVerificationState> {
  @override
  SellerVerificationState build() => const SellerVerificationState();

  /// Step 2: look up the plate. Only PRIVATE vehicles pass — commercial /
  /// leasing / rental registrations are rejected (no dealers allowed).
  Future<void> verifyPlate(String rawPlate) async {
    state = state.copyWith(loading: true, clearError: true, clearCar: true);
    try {
      final data =
          await ref.read(govApiRepositoryProvider).lookupPlate(rawPlate);

      if (!data.isPrivate) {
        state = state.copyWith(
          loading: false,
          error:
              'הרכב רשום כ"${data.ownershipType}" ולא כרכב פרטי. ניתן לאמת רק בעלים פרטיים.',
        );
        return;
      }

      state = state.copyWith(loading: false, carData: data);
    } on GovApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'האימות נכשל. נסה שוב.');
    }
  }

  void setName(String name) => state = state.copyWith(name: name);

  /// Step 3: persist verified:true + name + role:seller to Firestore.
  Future<void> submit() async {
    if (state.carData == null) {
      state = state.copyWith(error: 'יש לאמת רכב תחילה.');
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .markVerifiedSeller(name: state.name.trim());
      // Refresh the cached user model so the router gate sees verified:true.
      ref.invalidate(currentUserModelProvider);
      state = state.copyWith(loading: false, saved: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'שמירת האימות נכשלה. ודא שאתה מחובר ונסה שוב.',
      );
    }
  }

  void reset() => state = const SellerVerificationState();
}

final sellerVerificationControllerProvider =
    NotifierProvider<SellerVerificationController, SellerVerificationState>(
  SellerVerificationController.new,
);
