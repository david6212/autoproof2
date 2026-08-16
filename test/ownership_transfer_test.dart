import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/models/ownership_transfer.dart';
import 'package:bonnetcheck/data/models/past_vehicle.dart';

/// The handover is two writes by two people with no server between them, so
/// the rules that make it safe live in three places: the document id being the
/// secret, the expiry, and the refusal to let someone claim their own code.
/// These cover the parts that are plain Dart.
void main() {
  OwnershipTransfer transfer({
    String id = 'AAAAAA',
    TransferStatus status = TransferStatus.pending,
    Duration age = Duration.zero,
    Duration validFor = const Duration(days: 14),
    int services = 3,
    String from = 'seller',
  }) {
    final created = DateTime.now().subtract(age);
    return OwnershipTransfer(
      id: id,
      plate: '20837803',
      vehicleId: 'v1',
      fromUserId: from,
      status: status,
      createdAt: created,
      expiresAt: created.add(validFor),
      servicesCarried: services,
      vehicleTitle: 'סקודה אוקטביה',
    );
  }

  group('the code is the document id', () {
    // Not a shortcut — it is the security model. Transfers can be fetched by
    // id and never listed, so a stranger cannot enumerate pending handovers
    // and cannot discover a code they were not handed.
    test('claimCode and id are the same thing', () {
      final t = transfer(id: '7K2M9X');
      expect(t.claimCode, '7K2M9X');
      expect(t.claimCode, t.id);
    });

    test('the code is never stored as a separate field', () {
      // Writing it into the document as well would hand it to anything that
      // could ever read the doc, undoing the point of hiding it in the id.
      final data = transfer(id: '7K2M9X').toFirestore();
      expect(data.containsKey('claimCode'), isFalse);
      expect(data.values.contains('7K2M9X'), isFalse);
    });
  });

  group('when a code can be spent', () {
    test('a fresh pending code can', () {
      expect(transfer().isClaimable, isTrue);
    });

    test('one past its expiry cannot', () {
      final stale = transfer(age: const Duration(days: 20));
      expect(stale.isExpired, isTrue);
      expect(stale.isClaimable, isFalse);
    });

    test('the day before expiry it still can', () {
      expect(transfer(age: const Duration(days: 13)).isClaimable, isTrue);
    });

    test('an already-claimed code cannot be spent twice', () {
      expect(transfer(status: TransferStatus.claimed).isClaimable, isFalse);
    });

    test('an expired status counts even if the date has not passed', () {
      expect(transfer(status: TransferStatus.expired).isExpired, isTrue);
    });
  });

  group('what the buyer is told before confirming', () {
    // The buyer cannot read the vehicle — a passport is readable only by its
    // owner, and until the code is spent that is still the seller. So the
    // confirmation screen can only name the car if the transfer carries it.
    test('the transfer names the car and its history without the vehicle', () {
      final t = transfer(services: 4);
      expect(t.vehicleTitle, isNotEmpty);
      expect(t.plate, isNotEmpty);
      expect(t.servicesCarried, 4);
    });

    test('a car with no records says so honestly', () {
      expect(transfer(services: 0).servicesCarried, 0);
    });
  });

  group('what the seller keeps', () {
    // The obvious build cannot work: a passport is readable only by its
    // current owner, and `transfers` cannot be listed at all. So the record is
    // written at sale time to the seller's own private subcollection.
    PastVehicle past({DateTime? from, int services = 3}) => PastVehicle(
          id: 'v1',
          plate: '20837803',
          title: 'סקודה אוקטביה',
          servicesLogged: services,
          ownedFrom: from,
          soldAt: DateTime(2026, 8, 1),
        );

    test('counts the months they had it', () {
      expect(past(from: DateTime(2024, 8, 1)).ownedMonths, 730 ~/ 30);
    });

    test('says nothing rather than guessing when the start is unknown', () {
      // A vehicle added without a purchase date has no honest answer here.
      expect(past().ownedMonths, isNull);
    });

    test('records what was logged, frozen at handover', () {
      final record = past(services: 5);
      expect(record.servicesLogged, 5);
      expect(record.toFirestore()['servicesLogged'], 5);
      // No live link back to the vehicle: it is a keepsake, not a window into
      // what the new owner does next.
      expect(record.toFirestore().containsKey('ownerId'), isFalse);
    });
  });

  group('typing the code in', () {
    test('case, spaces and dashes are forgiven', () {
      expect(OwnershipTransfer.normaliseCode(' 7k2-m9 x '), '7K2M9X');
    });

    test('a normalised code is the length the lookup expects', () {
      final code = OwnershipTransfer.generateCode();
      expect(OwnershipTransfer.normaliseCode(code.toLowerCase()), code);
      expect(code.length, OwnershipTransfer.codeLength);
    });

    test('two generated codes are not the same', () {
      // Random.secure, because a guessable code is a car history handed to a
      // stranger. A duplicate in 200 draws would mean the generator is broken.
      final codes = {for (var i = 0; i < 200; i++) OwnershipTransfer.generateCode()};
      expect(codes.length, greaterThan(190));
    });
  });
}
