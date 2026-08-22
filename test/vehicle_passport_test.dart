import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/ownership_transfer.dart';
import 'package:bonnetcheck/data/models/service_record.dart';
import 'package:bonnetcheck/data/models/vehicle.dart';
import 'package:bonnetcheck/data/models/vehicle_reminder.dart';
import 'package:bonnetcheck/data/repositories/vehicle_repository.dart';

Vehicle _vehicle({
  int serviceCount = 0,
  DateTime? first,
  DateTime? last,
  DateTime? recallChecked,
}) =>
    Vehicle(
      id: 'v1',
      plate: '12345678',
      ownerId: 'u1',
      serviceCount: serviceCount,
      firstServiceAt: first,
      lastServiceAt: last,
      lastRecallCheckAt: recallChecked,
      createdAt: DateTime(2026, 1, 1),
    );

ServiceRecord _record({int km = 50000, String? corrects}) => ServiceRecord(
      id: 's1',
      type: ServiceType.routine,
      title: 'טיפול',
      date: DateTime(2026, 5, 1),
      km: km,
      addedByOwnerId: 'u1',
      createdAt: DateTime(2026, 5, 1),
      correctsServiceId: corrects,
    );

void main() {
  group('the תיק מתועד badge', () {
    // Both halves of the rule carry weight. Three receipts entered in one
    // evening say nothing about how a car was kept; the six-month span is what
    // makes the badge mean "someone has been logging this as they go".
    test('needs three records AND six months of span', () {
      final enough = _vehicle(
        serviceCount: 3,
        first: DateTime(2025, 1, 1),
        last: DateTime(2025, 8, 1),
      );
      expect(enough.hasDocumentedHistory, isTrue);
    });

    test('three records crammed into one week do not earn it', () {
      final crammed = _vehicle(
        serviceCount: 3,
        first: DateTime(2025, 1, 1),
        last: DateTime(2025, 1, 7),
      );
      expect(crammed.historySpanMonths, 0);
      expect(crammed.hasDocumentedHistory, isFalse);
    });

    test('two records over two years do not earn it either', () {
      final sparse = _vehicle(
        serviceCount: 2,
        first: DateTime(2023, 1, 1),
        last: DateTime(2025, 1, 1),
      );
      expect(sparse.hasDocumentedHistory, isFalse);
    });

    test('an empty passport spans nothing and claims nothing', () {
      final empty = _vehicle();
      expect(empty.historySpanMonths, 0);
      expect(empty.hasDocumentedHistory, isFalse);
    });
  });

  group('recall checks', () {
    test('a passport never checked is due', () {
      expect(_vehicle().needsRecallCheck, isTrue);
    });

    test('checked an hour ago is not due again', () {
      final v = _vehicle(
        recallChecked: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(v.needsRecallCheck, isFalse);
    });

    test('checked yesterday is due', () {
      final v = _vehicle(
        recallChecked: DateTime.now().subtract(const Duration(hours: 25)),
      );
      expect(v.needsRecallCheck, isTrue);
    });
  });

  group('service records', () {
    test('a plain record is not a correction', () {
      expect(_record().isCorrection, isFalse);
    });

    test('a record pointing at another one is', () {
      expect(_record(corrects: 'earlier').isCorrection, isTrue);
    });
  });

  group('handover codes', () {
    test('are six characters from the unambiguous alphabet', () {
      for (var i = 0; i < 200; i++) {
        final code = OwnershipTransfer.generateCode();
        expect(code.length, OwnershipTransfer.codeLength);
        // O/0, I/1 and Q are excluded: the code gets read aloud in a car park.
        expect(RegExp(r'^[A-HJ-NPR-Z2-9]+$').hasMatch(code), isTrue,
            reason: 'ambiguous character in $code');
      }
    });

    test('what the buyer types is forgiven for case, spaces and dashes', () {
      expect(OwnershipTransfer.normaliseCode(' 7k2-m9x '), '7K2M9X');
    });

    test('a fresh handover is claimable and an old one is not', () {
      final fresh = OwnershipTransfer(
        id: 'AAAAAA',
        plate: '12345678',
        vehicleId: 'v1',
        fromUserId: 'u1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 14)),
      );
      expect(fresh.isClaimable, isTrue);

      final stale = OwnershipTransfer(
        id: 'BBBBBB',
        plate: '12345678',
        vehicleId: 'v1',
        fromUserId: 'u1',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        expiresAt: DateTime.now().subtract(const Duration(days: 6)),
      );
      expect(stale.isExpired, isTrue);
      expect(stale.isClaimable, isFalse);
    });

    test('an already-claimed handover cannot be claimed again', () {
      final claimed = OwnershipTransfer(
        id: 'CCCCCC',
        plate: '12345678',
        vehicleId: 'v1',
        fromUserId: 'u1',
        toUserId: 'u2',
        status: TransferStatus.claimed,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 14)),
      );
      expect(claimed.isClaimable, isFalse);
    });
  });

  group('reminders', () {
    VehicleReminder due(int inDays, {bool isDone = false}) => VehicleReminder(
          id: 'r',
          type: ReminderType.test,
          title: 'טסט',
          dueDate: DateTime.now().add(Duration(days: inDays)),
          isDone: isDone,
          createdAt: DateTime.now(),
        );

    test('surfaces three weeks out, stays quiet before that', () {
      expect(due(30).isDueSoon, isFalse);
      expect(due(21).isDueSoon, isTrue);
      expect(due(3).isDueSoon, isTrue);
    });

    test('an overdue reminder is both overdue and still surfaced', () {
      final late = due(-5);
      expect(late.isOverdue, isTrue);
      expect(late.isDueSoon, isTrue);
    });

    test('a done reminder stops nagging', () {
      expect(due(-5, isDone: true).isOverdue, isFalse);
      expect(due(2, isDone: true).isDueSoon, isFalse);
    });

    test('a mileage-only reminder has no countdown', () {
      final byKm = VehicleReminder(
        id: 'r',
        type: ReminderType.serviceKm,
        title: 'טיפול 100,000',
        dueKm: 100000,
        createdAt: DateTime.now(),
      );
      expect(byKm.daysUntilDue, isNull);
      expect(byKm.isDueSoon, isFalse);
    });
  });

  group('plates', () {
    // One car is one passport whether the owner typed dashes or not.
    test('normalise to digits only', () {
      expect(VehicleRepository.normalisePlate('123-45-678'), '12345678');
      expect(VehicleRepository.normalisePlate(' 99-999-999 '), '99999999');
    });
  });
}
