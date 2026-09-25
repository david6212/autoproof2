import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_config.dart';
import '../../data/repositories/operator_inbox_repository.dart';
import 'auth_provider.dart';

final operatorInboxRepositoryProvider = Provider<OperatorInboxRepository>(
  (ref) => OperatorInboxRepository(FirebaseFirestore.instance),
);

/// Whether the signed-in account is the operator.
///
/// Matches what `firestore.rules` checks, including the verified-email part:
/// a UI that offers a control the rules will refuse is worse than no control,
/// because the failure arrives as an error rather than as an absence.
final isOperatorProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return false;
  return user.emailVerified &&
      (user.email ?? '').toLowerCase() == AppConfig.operatorEmail.toLowerCase();
});

/// Every unanswered request, both kinds, oldest first.
///
/// Empty for everybody who is not the operator — the streams are never opened,
/// so no read is spent and no rule is tested.
final operatorInboxProvider = StreamProvider<List<InboxItem>>((ref) {
  if (!ref.watch(isOperatorProvider)) return Stream.value(const []);
  final repo = ref.watch(operatorInboxRepositoryProvider);

  // The escort applications queue is only watched when that feature is on.
  // Opening a stream on a collection no screen can write to would spend a
  // read to be told, every time, that nobody applied.
  return repo.watch(InboxKind.correction).asyncExpand((corrections) {
    return repo.watch(InboxKind.noteReport).asyncExpand((notes) {
      return repo.watch(InboxKind.reviewReport).asyncExpand((reviews) {
        final head = [...corrections, ...notes, ...reviews];
        if (!AppConfig.escortEnabled) return Stream.value(_oldestFirst(head));
        return repo
            .watch(InboxKind.proApplication)
            .map((pros) => _oldestFirst([...head, ...pros]));
      });
    });
  });
});

/// The oldest request first: it is the one closest to breaking the fourteen
/// days, which is the only ordering this list has a reason to use.
List<InboxItem> _oldestFirst(List<InboxItem> items) {
  return [...items]..sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    });
}
