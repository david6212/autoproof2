import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../data/models/escort_pro.dart';
import '../../data/repositories/escort_repository.dart';
import 'gov_api_provider.dart';

final escortRepositoryProvider = Provider<EscortRepository>((ref) {
  return EscortRepository(
    firestore: FirebaseFirestore.instance,
    gov: ref.watch(govApiRepositoryProvider),
  );
});

/// The professionals a buyer can choose from, optionally narrowed to an area.
///
/// **Returns an empty list while the feature is off** rather than reading the
/// collection. The flag is a legal hold, not a UI preference: until the
/// wording is settled, nothing about this feature should reach a screen, and
/// nothing should be read on its behalf either.
final escortProsProvider =
    StreamProvider.family<List<EscortPro>, String?>((ref, area) {
  if (!AppConfig.escortEnabled) return Stream.value(const []);
  return ref.watch(escortRepositoryProvider).watchAvailable(area: area);
});

final escortProProvider =
    FutureProvider.family<EscortPro?, String>((ref, id) async {
  if (!AppConfig.escortEnabled) return null;
  return ref.watch(escortRepositoryProvider).byId(id);
});
