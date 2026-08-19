import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gov_data_model.dart';
import '../../data/models/vehicle_reminder.dart';
import '../../data/repositories/vehicle_repository.dart';
import 'auth_provider.dart';
import 'vehicle_provider.dart';

/// A passport somebody built before they had an account.
///
/// The garage used to open on a login wall: a stranger was asked to commit
/// before they had seen anything of their own. This holds what they built
/// instead — their real car, pulled from the registry — so that signing in
/// stops being the price of entry and becomes the way to keep something they
/// already have on screen.
class VehicleDraft {
  const VehicleDraft({
    required this.gov,
    this.nickname = '',
    this.currentKm = 0,
  });

  /// What the Ministry of Transport returned for the plate. Held whole so the
  /// saved passport carries the same snapshot an ordinary add would.
  final GovData gov;

  final String nickname;
  final int currentKm;

  VehicleDraft copyWith({String? nickname, int? currentKm}) => VehicleDraft(
        gov: gov,
        nickname: nickname ?? this.nickname,
        currentKm: currentKm ?? this.currentKm,
      );
}

/// The draft, and the one operation that turns it into a real passport.
///
/// Deliberately NOT auto-disposed. Signing in tears down the whole navigation
/// stack — the login screen ends on `context.go`, which leaves nothing of the
/// garage behind — so a draft scoped to the screen would be collected at the
/// exact moment it becomes valuable. This one outlives that.
class VehicleDraftController extends Notifier<VehicleDraft?> {
  @override
  VehicleDraft? build() => null;

  void hold(VehicleDraft draft) => state = draft;

  void clear() => state = null;

  /// Writes the held draft to the signed-in owner's garage.
  ///
  /// Returns the vehicle id, or null if there was nothing to claim or nobody
  /// to claim it. Clears the draft either way it succeeds, so a rebuild cannot
  /// create the car twice.
  Future<String?> claim() async {
    final draft = state;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (draft == null || uid == null) return null;

    final repo = ref.read(vehicleRepositoryProvider);
    final plate = VehicleRepository.normalisePlate(draft.gov.plate);

    // The guest lookup could not run the duplicate check — it needs a uid.
    // Someone who already had this car in their garage and typed it again
    // while signed out must land on the car they have, not on a second copy
    // of it with none of their service records.
    final existing = await repo.findMyVehicleByPlate(uid, plate);
    if (existing != null) {
      state = null;
      return existing.id;
    }

    final gov = draft.gov;
    final id = await repo.createVehicle(
      ownerId: uid,
      plate: plate,
      nickname: draft.nickname,
      currentKm: draft.currentKm,
      govSnapshot: {
        'make': gov.make,
        'model': gov.commercialName.isNotEmpty ? gov.commercialName : gov.model,
        'year': gov.year,
        'color': gov.color,
        'fuelType': gov.fuelType,
        'trim': gov.trim,
        'lastTestKm': gov.lastTestKm,
        'licenseExpiry': gov.licenseExpiry,
        'tozeretCd': gov.tozeretCd,
        'degemCd': gov.degemCd,
      },
    );

    // Same single derived reminder an ordinary add creates. The test expiry is
    // the only date official data actually gives us; anything else would be us
    // inventing a service interval for a car we know nothing about.
    final expiry = gov.licenseExpiry;
    if (expiry != null) {
      await repo.addReminder(
        id,
        VehicleReminder(
          id: '',
          type: ReminderType.test,
          title: 'טסט שנתי',
          dueDate: expiry,
          source: ReminderSource.auto,
          createdAt: DateTime.now(),
        ),
      );
    }

    state = null;
    return id;
  }
}

final vehicleDraftProvider =
    NotifierProvider<VehicleDraftController, VehicleDraft?>(
  VehicleDraftController.new,
);
