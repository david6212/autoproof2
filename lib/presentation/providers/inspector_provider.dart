import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/inspector_model.dart';
import '../../data/repositories/inspector_repository.dart';

final inspectorRepositoryProvider = Provider<InspectorRepository>((ref) {
  return InspectorRepository();
});

final inspectorsProvider = StreamProvider<List<InspectorModel>>((ref) {
  return ref.watch(inspectorRepositoryProvider).streamInspectors();
});

final inspectorByIdProvider =
    FutureProvider.family<InspectorModel?, String>((ref, id) async {
  return ref.watch(inspectorRepositoryProvider).getInspector(id);
});
