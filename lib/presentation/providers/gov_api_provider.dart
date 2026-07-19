import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/gov_data_model.dart';
import '../../data/repositories/gov_api_repository.dart';
import '../../data/sources/remote/gov_api_service.dart';

final govApiRepositoryProvider = Provider<GovApiRepository>((ref) {
  return GovApiRepository();
});

/// Holds the result of a single plate lookup.
/// - AsyncData(null): idle, nothing searched yet
/// - AsyncLoading: searching
/// - AsyncData(GovData): success
/// - AsyncError: failure (message is Hebrew)
class GovLookupController extends AutoDisposeAsyncNotifier<GovData?> {
  @override
  Future<GovData?> build() async => null;

  Future<void> search(String rawPlate) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await ref.read(govApiRepositoryProvider).lookupPlate(rawPlate);
      } on GovApiException catch (e) {
        throw e.message; // surface the Hebrew message as the error object
      }
    });
  }

  void clear() => state = const AsyncData(null);
}

final govLookupControllerProvider =
    AutoDisposeAsyncNotifierProvider<GovLookupController, GovData?>(
  GovLookupController.new,
);
