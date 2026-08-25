import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/service_record.dart';

/// Service records became editable on 25/08/2026, on David's instruction:
/// typos happen, and the correction flow — a second record pointing at the
/// first — was more machinery than the problem needed.
///
/// The three things that had to travel with that decision are pinned here.
/// Editing a history that buyers are shown as evidence is only defensible
/// while all three hold.
void main() {
  ServiceRecord original() => ServiceRecord(
        id: 's1',
        type: ServiceType.routine,
        title: 'טיפול 60,000',
        date: DateTime(2026, 2, 10),
        km: 168400, // the typo: a digit too many
        cost: 1200,
        garageName: 'מוסך אבי ובניו',
        addedByOwnerId: 'owner-1',
        createdAt: DateTime(2026, 2, 11),
      );

  ServiceRecord fixed() => original().edited(
        type: ServiceType.routine,
        title: 'טיפול 60,000',
        date: DateTime(2026, 2, 10),
        km: 68400,
        cost: 1200,
        garageName: 'מוסך אבי ובניו',
        at: DateTime(2026, 8, 25),
      );

  group('1 — an edit stamps itself', () {
    test('the record says it was changed, and when', () {
      expect(original().wasEdited, isFalse);
      final e = fixed();
      expect(e.wasEdited, isTrue);
      expect(e.editedAt, DateTime(2026, 8, 25));
    });

    test('the stamp is written, and a record without one reads as unedited',
        () {
      expect(fixed().toFirestore()['editedAt'], DateTime(2026, 8, 25));
      // Every record written before 25/08 has no such field.
      expect(
        ServiceRecord.fromFirestore(const {'title': 'x'}, 's1').wasEdited,
        isFalse,
      );
    });

    test('an untouched record carries no key at all', () {
      // Not `editedAt: null` on every document. The security rule tests the
      // field's presence, and a key that is always there would make "was this
      // changed?" a question about null rather than about presence.
      expect(original().toFirestore().containsKey('editedAt'), isFalse);
    });
  });

  group('2 — an edit cannot change whose record it is', () {
    test('the author and the creation time travel through untouched', () {
      final e = fixed();
      expect(e.addedByOwnerId, 'owner-1');
      expect(e.createdAt, DateTime(2026, 2, 11));
      expect(e.id, 's1');
    });

    test('the rules pin both, and demand the stamp', () {
      final rules = File('firestore.rules').readAsStringSync();
      final block = rules.substring(rules.indexOf('match /services/{serviceId}'));
      expect(block, contains(
          'request.resource.data.addedByOwnerId == resource.data.addedByOwnerId'));
      expect(block,
          contains('request.resource.data.createdAt == resource.data.createdAt'));
      expect(block, contains('request.resource.data.editedAt is timestamp'));
    });

    test('the write path does not resend the pinned fields', () {
      // A Firestore timestamp carries nanoseconds and a Dart DateTime only
      // microseconds, so a createdAt read into the model and written back is
      // not always byte-identical — and the rule compares them exactly.
      final repo = File('lib/data/repositories/service_repository.dart')
          .readAsStringSync();
      expect(repo, contains("..remove('createdAt')"));
      expect(repo, contains("..remove('addedByOwnerId')"));
    });
  });

  group('3 — deletion is still refused', () {
    test('the rules say so', () {
      final rules = File('firestore.rules').readAsStringSync();
      final block = rules.substring(rules.indexOf('match /services/{serviceId}'));
      expect(block, contains('allow delete: if false'));
    });

    test('the repository has no method that could try', () {
      final repo = File('lib/data/repositories/service_repository.dart')
          .readAsStringSync();
      // The identifier appears in the class comment saying it must not
      // exist, so this looks for a declaration rather than the word.
      expect(repo.contains('Future<void> deleteService'), isFalse);
      expect(repo.contains('.delete()'), isFalse);
      expect(repo, contains('Future<void> updateService'));
    });
  });

  test('the mileage the vehicle shows is recomputed after an edit', () {
    // `currentKm` is a denormalised copy of the highest reading. Editing the
    // record that set it would otherwise leave the car advertising a mileage
    // no record supports — which is the exact discrepancy the app exists to
    // point out on other people's listings.
    final repo =
        File('lib/data/repositories/service_repository.dart').readAsStringSync();
    final method = repo.substring(repo.indexOf('Future<void> updateService'));
    expect(method, contains("batch.update(_vehicle(vehicleId), {'currentKm'"));
  });

  test('nothing still tells a buyer the records cannot be edited', () {
    // The claim was in four places. An app that lets an owner edit while
    // telling buyers it does not is worse than either choice made honestly.
    for (final path in [
      'lib/presentation/widgets/service_timeline.dart',
      'lib/presentation/screens/buyer/add_service_screen.dart',
      'lib/presentation/screens/buyer/vehicle_detail_screen.dart',
      'lib/core/constants/app_strings.dart',
    ]) {
      final src = File(path).readAsStringSync();
      for (final claim in [
        'אינן ניתנות לעריכה',
        'לא ניתן לערוך',
        'לא ניתן לשנותו',
      ]) {
        expect(src.contains(claim), isFalse, reason: '$path: $claim');
      }
    }
  });
}
