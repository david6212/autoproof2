import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/car_model.dart';
import '../../data/repositories/storage_repository.dart';
import 'auth_provider.dart';
import 'cars_provider.dart';
import 'seller_verification_provider.dart';
import '../../core/utils/validators.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository();
});

class CreateListingState {
  final List<XFile> photos;
  final String price;
  final String km;
  final String area;
  final String reason;
  final String description; // "a few words about the car"
  /// 0 = the car, 1 = price & details, 2 = photos, 3 = publish.
  final int step;
  final bool publishing;
  final String? error;
  final String? publishedId;

  const CreateListingState({
    this.photos = const [],
    this.price = '',
    this.km = '',
    this.area = '',
    this.reason = '',
    this.description = '',
    this.step = 0,
    this.publishing = false,
    this.error,
    this.publishedId,
  });

  CreateListingState copyWith({
    List<XFile>? photos,
    String? price,
    String? km,
    String? area,
    String? reason,
    String? description,
    int? step,
    bool? publishing,
    String? error,
    String? publishedId,
    bool clearError = false,
  }) {
    return CreateListingState(
      photos: photos ?? this.photos,
      price: price ?? this.price,
      km: km ?? this.km,
      area: area ?? this.area,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      step: step ?? this.step,
      publishing: publishing ?? this.publishing,
      error: clearError ? null : (error ?? this.error),
      publishedId: publishedId ?? this.publishedId,
    );
  }
}

class CreateListingController extends Notifier<CreateListingState> {
  @override
  CreateListingState build() => const CreateListingState();

  void addPhotos(List<XFile> picked) {
    final combined = [...state.photos, ...picked].take(12).toList();
    state = state.copyWith(photos: combined);
  }

  void removePhoto(int index) {
    final list = [...state.photos]..removeAt(index);
    state = state.copyWith(photos: list);
  }

  void setPrice(String v) => state = state.copyWith(price: v);
  void setKm(String v) => state = state.copyWith(km: v);
  void setArea(String v) => state = state.copyWith(area: v);
  void setReason(String v) => state = state.copyWith(reason: v);
  void setDescription(String v) => state = state.copyWith(description: v);

  /// The last step's index. Named rather than written as a literal in two
  /// places, which is how a flow ends up with a step nobody can leave.
  static const lastStep = 3;

  void next() {
    if (state.step < lastStep) {
      state = state.copyWith(step: state.step + 1, clearError: true);
    }
  }

  void back() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1, clearError: true);
  }

  /// Whether step 1 is done: a car came back from the registry, and a
  /// first-time seller has given the name buyers will see.
  bool carValid({required bool needsName}) {
    final v = ref.read(sellerVerificationControllerProvider);
    if (v.carData == null) return false;
    return !needsName || v.name.trim().length >= 2;
  }

  bool get detailsValid {
    final p = double.tryParse(state.price) ?? 0;
    final k = int.tryParse(state.km) ?? -1;
    return p > 0 && k >= 0 && state.area.trim().isNotEmpty;
  }

  /// Non-null when the entered km is below the official last-test reading.
  ///
  /// Surfaced as a warning the seller must acknowledge, not a block: an
  /// odometer can be legitimately replaced and the registry reading can be
  /// stale, so refusing outright would assert more than we checked. The
  /// discrepancy is shown to buyers either way, by PlateHistoryCard.
  String? get kmWarning {
    final car = ref.read(sellerVerificationControllerProvider).carData;
    final entered = int.tryParse(state.km);
    if (car == null || entered == null) return null;
    return Validators.kmAgainstLastTest(
      enteredKm: entered,
      lastTestKm: car.lastTestKm,
    );
  }

  Future<void> publish() async {
    final verification = ref.read(sellerVerificationControllerProvider);
    final car = verification.carData;
    if (car == null) {
      state = state.copyWith(error: 'יש לאמת רכב תחילה (מסך אימות מוכר).');
      return;
    }

    final price = double.tryParse(state.price) ?? 0;
    final km = int.tryParse(state.km) ?? -1;
    if (price <= 0 || km < 0) {
      state = state.copyWith(error: 'בדוק את המחיר והקילומטראז\'.');
      return;
    }

    // The two gates that used to stand in front of the whole flow, as a
    // router redirect, now stand here — at the last possible moment, which is
    // the only moment where the reason for them is obvious.
    //
    // They are not weaker for having moved: both were client-side before and
    // are client-side now. What changed is that a seller sees their own car
    // and prices it before being asked to prove anything.
    final user = ref.read(currentUserModelProvider).valueOrNull;
    if (user != null && !user.hasPhone) {
      state = state.copyWith(error: 'צריך לאמת מספר טלפון לפני הפרסום.');
      return;
    }
    if (user != null && !user.verified) {
      await ref.read(sellerVerificationControllerProvider.notifier).submit();
      final v = ref.read(sellerVerificationControllerProvider);
      if (!v.saved) {
        state = state.copyWith(
            error: v.error ?? 'שמירת האימות נכשלה. נסה שוב.');
        return;
      }
    }

    // A guest may walk the whole flow — that is the point of it — but a
    // listing has an owner. This used to fall back to a literal 'test-user'
    // uid "so the flow is testable before auth is wired", which stopped being
    // a convenience the moment the flow opened to visitors: it would have
    // published real cars under an account nobody can sign in to, and so
    // nobody could ever edit or remove.
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      state = state.copyWith(error: 'צריך חשבון כדי לפרסם מודעה.');
      return;
    }
    final carRepo = ref.read(carRepositoryProvider);

    state = state.copyWith(publishing: true, clearError: true);
    try {
      // RULE 2 — one active listing per seller.
      if (await carRepo.hasActiveListing(uid)) {
        state = state.copyWith(
          publishing: false,
          error: 'כבר יש לך מודעה פעילה. ניתן לפרסם רכב אחד בכל פעם.',
        );
        return;
      }

      final model = CarModel(
        id: '',
        plate: car.plate,
        make: car.make,
        model: car.commercialName.isNotEmpty ? car.commercialName : car.model,
        year: car.year,
        price: price,
        km: km,
        hand: 1,
        area: state.area.trim(),
        sellerId: uid,
        status: CarStatus.active,
        govData: {
          'fuelType': car.fuelType,
          'color': car.color,
          'ownershipType': car.ownershipType,
        },
        // The registry's full answer, stored with the listing so a buyer can
        // read it without holding the plate. No plate and no VIN inside — see
        // GovData.toSnapshot.
        govSnapshot: car.toSnapshot(),
        govCheckedAt: DateTime.now(),
        // This plate's earlier listings, fetched here because the seller is
        // the last person in the flow who holds the plate. Without it the
        // odometer-rollback check — the app's signature finding — would have
        // no past to compare against once buyers stop getting the plate.
        plateHistorySnapshot: [
          for (final snap in await carRepo.getPlateHistory(car.plate))
            snap.toMap(),
        ],
        // Official fields stored top-level so the buyer filters can use them.
        fuel: car.fuelType,
        color: car.color,
        ownership: car.ownershipType,
        // Per-model build spec (engine cc, seats, drivetrain, body type). Saved
        // at publish time so filtering never needs a per-listing API call.
        spec: car.spec,
        photos: const [],
        reasonForSelling: state.reason.trim(),
        description: state.description.trim(),
        sellerType: verification.sellerType,
        createdAt: DateTime.now(),
      );

      final id = await carRepo.createListing(model);

      // Record a plate snapshot so this car can be cross-checked if relisted
      // later (odometer rollback, price history). Best-effort.
      try {
        await carRepo.recordPlateSnapshot(
          plate: model.plate,
          carId: id,
          km: model.km,
          price: model.price,
          sellerType: model.sellerType,
          area: model.area,
        );
      } catch (_) {
        // Ignore — history is a bonus, must never block publishing.
      }

      // Best-effort photo upload; if Storage isn't available the listing
      // still publishes (with the placeholder image).
      if (state.photos.isNotEmpty) {
        try {
          final urls = await ref
              .read(storageRepositoryProvider)
              .uploadCarPhotos(uid: uid, listingId: id, photos: state.photos);
          await carRepo.updatePhotos(id, urls);
        } catch (_) {
          // Ignore upload failure — listing remains without photos.
        }
      }

      state = state.copyWith(publishing: false, publishedId: id);
    } catch (e) {
      state = state.copyWith(
        publishing: false,
        error: 'פרסום המודעה נכשל. נסה שוב.',
      );
    }
  }

  void reset() => state = const CreateListingState();
}

final createListingControllerProvider =
    NotifierProvider<CreateListingController, CreateListingState>(
  CreateListingController.new,
);
