import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/car_model.dart' show CarStatus;
import '../../data/models/expense.dart';
import '../../data/models/gov_data_model.dart';
import '../../data/models/ownership_transfer.dart';
import '../../data/models/service_record.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/vehicle_document.dart';
import '../../data/models/vehicle_reminder.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/repositories/transfer_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../data/sources/remote/gov_api_service.dart' show GovApiException;
import 'auth_provider.dart';
import 'cars_provider.dart' show carRepositoryProvider;
import 'create_listing_provider.dart' show storageRepositoryProvider;
import 'gov_api_provider.dart';

final vehicleRepositoryProvider =
    Provider<VehicleRepository>((ref) => VehicleRepository());

final serviceRepositoryProvider =
    Provider<ServiceRepository>((ref) => ServiceRepository());

final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) => ExpenseRepository());

final documentRepositoryProvider =
    Provider<DocumentRepository>((ref) => DocumentRepository());

/// The signed-in owner's garage. Empty for a guest — the passport is private
/// by definition, so there is nothing to show without an account.
final myVehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(vehicleRepositoryProvider).watchMyVehicles(uid);
});

final vehicleProvider = StreamProvider.family<Vehicle?, String>(
  (ref, id) => ref.watch(vehicleRepositoryProvider).watchVehicle(id),
);

final vehicleServicesProvider =
    StreamProvider.family<List<ServiceRecord>, String>(
  (ref, id) => ref.watch(serviceRepositoryProvider).watchServices(id),
);

final vehicleRemindersProvider =
    StreamProvider.family<List<VehicleReminder>, String>(
  (ref, id) => ref.watch(vehicleRepositoryProvider).watchReminders(id),
);

final vehicleExpensesProvider = StreamProvider.family<List<Expense>, String>(
  (ref, id) => ref.watch(expenseRepositoryProvider).watchExpenses(id),
);

final vehicleDocumentsProvider =
    StreamProvider.family<List<VehicleDocument>, String>(
  (ref, id) => ref.watch(documentRepositoryProvider).watchDocuments(id),
);

/// The buyer's view of a listed car's documents — only what the owner shared.
///
/// A one-shot read rather than a stream: a visitor reading a listing does not
/// need live updates, and the query is constrained to shared documents because
/// the rules would refuse anything broader.
final sharedDocumentsProvider =
    FutureProvider.family<List<VehicleDocument>, String>((ref, id) async {
  try {
    return await ref.watch(documentRepositoryProvider).sharedDocuments(id);
  } catch (_) {
    // A car that has been de-listed closes its documents again. That is the
    // rule working, not an error worth showing anyone.
    return const [];
  }
});

/// Checks the government recall dataset for every car in the garage that has
/// not been checked today, and stores what it found.
///
/// This is the Spark-plan substitute for the spec's nightly Cloud Function.
/// There is no server to notice a new recall while the app is shut, so the
/// check happens when the owner opens their garage. That is later than a push
/// notification would be, and it is honest — the app never implies it is
/// watching in the background.
///
/// Failures are swallowed on purpose. A recall check that cannot reach the API
/// must not take down the garage, and the last known count stays on screen.
final recallWatchProvider = FutureProvider<void>((ref) async {
  final vehicles = ref.watch(myVehiclesProvider).valueOrNull ?? const [];
  final repo = ref.read(vehicleRepositoryProvider);
  final gov = ref.read(govApiRepositoryProvider);

  for (final v in vehicles) {
    if (!v.needsRecallCheck) continue;
    try {
      final data = await gov.lookupPlate(v.plate);
      await repo.markRecallChecked(v.id, data.recalls.length);
    } catch (_) {
      // Leave both fields alone, so the next open tries again rather than
      // recording a zero that was never measured.
    }
  }
});

/// Reminders across the whole garage that are due within three weeks, soonest
/// first. Drives the badge on the tab and the banner at the top of the garage.
final dueRemindersProvider = Provider<List<(Vehicle, VehicleReminder)>>((ref) {
  final vehicles = ref.watch(myVehiclesProvider).valueOrNull ?? const [];
  final due = <(Vehicle, VehicleReminder)>[];
  for (final v in vehicles) {
    final reminders = ref.watch(vehicleRemindersProvider(v.id)).valueOrNull;
    for (final r in reminders ?? const <VehicleReminder>[]) {
      if (r.isDueSoon) due.add((v, r));
    }
  }
  due.sort((a, b) =>
      (a.$2.daysUntilDue ?? 9999).compareTo(b.$2.daysUntilDue ?? 9999));
  return due;
});

/// What the add-vehicle screen is doing right now.
enum AddVehicleStep { enterPlate, confirm, saving, done }

class AddVehicleState {
  final AddVehicleStep step;
  final GovData? found;
  final String? error;
  final String? createdVehicleId;

  /// Set when the plate is already in this owner's garage — adding it twice
  /// would split one car's history across two passports.
  final Vehicle? alreadyOwned;

  const AddVehicleState({
    this.step = AddVehicleStep.enterPlate,
    this.found,
    this.error,
    this.createdVehicleId,
    this.alreadyOwned,
  });

  AddVehicleState copyWith({
    AddVehicleStep? step,
    GovData? found,
    String? error,
    String? createdVehicleId,
    Vehicle? alreadyOwned,
    bool clearError = false,
  }) =>
      AddVehicleState(
        step: step ?? this.step,
        found: found ?? this.found,
        error: clearError ? null : (error ?? this.error),
        createdVehicleId: createdVehicleId ?? this.createdVehicleId,
        alreadyOwned: alreadyOwned ?? this.alreadyOwned,
      );
}

/// Plate → official lookup → confirm → passport.
///
/// The lookup goes through the existing government engine. There is no second
/// API client here on purpose: the six datasets, the verified resource ids and
/// the Hebrew error messages already exist and are already tested.
class AddVehicleController extends AutoDisposeNotifier<AddVehicleState> {
  @override
  AddVehicleState build() => const AddVehicleState();

  Future<void> lookup(String rawPlate) async {
    final plate = VehicleRepository.normalisePlate(rawPlate);
    if (plate.length < 5) {
      state = state.copyWith(error: 'מספר רישוי לא תקין');
      return;
    }

    state = const AddVehicleState(step: AddVehicleStep.enterPlate);

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      final existing =
          await ref.read(vehicleRepositoryProvider).findMyVehicleByPlate(
                uid,
                plate,
              );
      if (existing != null) {
        state = state.copyWith(
          alreadyOwned: existing,
          error: 'הרכב הזה כבר נמצא ברשימה שלך',
        );
        return;
      }
    }

    try {
      final data = await ref.read(govApiRepositoryProvider).lookupPlate(plate);
      state = AddVehicleState(step: AddVehicleStep.confirm, found: data);
    } on GovApiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (_) {
      state = state.copyWith(error: 'לא הצלחנו לשלוף את נתוני הרכב');
    }
  }

  void back() => state = const AddVehicleState();

  /// Creates the passport, and the one reminder we can honestly derive.
  Future<String?> save({
    required String nickname,
    required int currentKm,
    DateTime? purchaseDate,
    int? purchasePrice,
  }) async {
    final car = state.found;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (car == null || uid == null) return null;

    state = state.copyWith(step: AddVehicleStep.saving, clearError: true);
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      final id = await repo.createVehicle(
        ownerId: uid,
        plate: car.plate,
        nickname: nickname,
        currentKm: currentKm,
        purchaseDate: purchaseDate,
        purchasePrice: purchasePrice,
        govSnapshot: {
          'make': car.make,
          'model': car.commercialName.isNotEmpty ? car.commercialName : car.model,
          'year': car.year,
          'color': car.color,
          'fuelType': car.fuelType,
          'trim': car.trim,
          'lastTestKm': car.lastTestKm,
          'licenseExpiry': car.licenseExpiry,
          'tozeretCd': car.tozeretCd,
          'degemCd': car.degemCd,
        },
      );

      // The test expiry is the only date we can derive from official data, so
      // it is the only reminder created automatically. Everything else is the
      // owner's to enter — inventing a service interval would be us making a
      // claim about their car.
      final expiry = car.licenseExpiry;
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

      state = state.copyWith(step: AddVehicleStep.done, createdVehicleId: id);
      return id;
    } catch (_) {
      state = state.copyWith(
        step: AddVehicleStep.confirm,
        error: 'לא הצלחנו לשמור את הרכב. נסו שוב',
      );
      return null;
    }
  }
}

final addVehicleControllerProvider =
    AutoDisposeNotifierProvider<AddVehicleController, AddVehicleState>(
  AddVehicleController.new,
);

/// Writes one service record, with its receipt if there is one.
///
/// The whole flow is a single method because a half-written record is worse
/// than none: the receipt is uploaded against an id reserved in advance, and
/// only then is the record committed together with the vehicle's counters.
class AddServiceController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit({
    required String vehicleId,
    required ServiceType type,
    required String title,
    required DateTime date,
    required int km,
    required int cost,
    String? garageName,
    String? notes,
    Uint8List? receiptBytes,
    String receiptContentType = 'image/jpeg',
    String? correctsServiceId,
  }) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return false;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final services = ref.read(serviceRepositoryProvider);
      final id = services.newServiceId(vehicleId);

      String? receiptUrl;
      if (receiptBytes != null) {
        // Best-effort: a failed upload must not cost the owner the record they
        // just typed out. They can add the receipt later as a correction.
        try {
          receiptUrl = await ref.read(storageRepositoryProvider).uploadServiceReceipt(
                uid: uid,
                vehicleId: vehicleId,
                serviceId: id,
                bytes: receiptBytes,
                contentType: receiptContentType,
              );
        } catch (_) {
          receiptUrl = null;
        }
      }

      await services.addService(
        vehicleId,
        ServiceRecord(
          id: id,
          type: type,
          title: title.trim(),
          date: date,
          km: km,
          cost: cost,
          garageName: (garageName ?? '').trim().isEmpty ? null : garageName!.trim(),
          notes: (notes ?? '').trim().isEmpty ? null : notes!.trim(),
          receiptUrl: receiptUrl,
          addedByOwnerId: uid,
          createdAt: DateTime.now(),
          correctsServiceId: correctsServiceId,
        ),
      );
    });

    state = result;
    return !result.hasError;
  }
}

final addServiceControllerProvider =
    AutoDisposeAsyncNotifierProvider<AddServiceController, void>(
  AddServiceController.new,
);

/// Add, fix and remove running costs.
///
/// Everything the service controller refuses to do, this one does — because
/// the two ledgers are answering different questions. This one is the owner's
/// budget and nobody else ever reads it.
class ExpenseActions {
  ExpenseActions(this._ref);

  final Ref _ref;

  Future<void> add(String vehicleId, Expense expense) =>
      _ref.read(expenseRepositoryProvider).addExpense(vehicleId, expense);

  Future<void> update(String vehicleId, Expense expense) =>
      _ref.read(expenseRepositoryProvider).updateExpense(vehicleId, expense);

  Future<void> remove(String vehicleId, String expenseId) =>
      _ref.read(expenseRepositoryProvider).deleteExpense(vehicleId, expenseId);
}

final expenseActionsProvider = Provider<ExpenseActions>(ExpenseActions.new);

/// Upload a document, share it, unshare it, delete it.
class DocumentActions {
  DocumentActions(this._ref);

  final Ref _ref;

  Future<String?> upload({
    required String vehicleId,
    required Uint8List bytes,
    required String fileName,
    required DocumentType type,
    required String title,
    String contentType = 'image/jpeg',
    bool shareWithBuyers = false,
  }) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return null;
    return _ref.read(documentRepositoryProvider).uploadDocument(
          uid: uid,
          vehicleId: vehicleId,
          bytes: bytes,
          fileName: fileName,
          type: type,
          title: title,
          contentType: contentType,
          shareWithBuyers: shareWithBuyers,
        );
  }

  Future<void> setShared(String vehicleId, String documentId, bool shared) =>
      _ref
          .read(documentRepositoryProvider)
          .setShared(vehicleId, documentId, shared);

  Future<void> remove(String vehicleId, VehicleDocument document) =>
      _ref.read(documentRepositoryProvider).deleteDocument(vehicleId, document);
}

final documentActionsProvider = Provider<DocumentActions>(DocumentActions.new);

final transferRepositoryProvider =
    Provider<TransferRepository>((ref) => TransferRepository());

/// Minting a handover code, and spending one.
class TransferActions {
  TransferActions(this._ref);

  final Ref _ref;

  Future<String> createFor(Vehicle vehicle, {String vehicleTitle = ''}) {
    return _ref.read(transferRepositoryProvider).createTransfer(
          vehicle: vehicle,
          carId: vehicle.activeCarId,
          vehicleTitle: vehicleTitle,
        );
  }

  /// Closes a listing without handing the passport to anyone — the car was
  /// sold outside the app, or the seller changed their mind.
  Future<void> closeWithoutTransfer(Vehicle vehicle, CarStatus status) {
    return _ref.read(carRepositoryProvider).closeListing(
          carId: vehicle.activeCarId!,
          status: status,
          vehicleId: vehicle.id,
        );
  }

  Future<OwnershipTransfer?> lookup(String code) =>
      _ref.read(transferRepositoryProvider).findByCode(code);

  Future<void> claim(OwnershipTransfer transfer) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) throw StateError('צריך להתחבר כדי לתבוע רכב');
    await _ref
        .read(transferRepositoryProvider)
        .claim(transfer: transfer, buyerUid: uid);
  }
}

final transferActionsProvider = Provider<TransferActions>(TransferActions.new);
