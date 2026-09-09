import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/utils/insurance_renewal.dart';
import 'package:bonnetcheck/data/models/expense.dart';
import 'package:bonnetcheck/data/models/service_record.dart';
import 'package:bonnetcheck/data/models/vehicle_reminder.dart';

/// The insurance renewal reminder.
///
/// The one renewal where forgetting is not an inconvenience: an uninsured car
/// on the road. Insurance was already a choice in the add-reminder sheet, so
/// the feature was never missing — **the question was**. An owner who never
/// opened that sheet was never asked, and so was never reminded.
void main() {
  final now = DateTime(2026, 8, 27);

  ServiceRecord service(ServiceType type, DateTime date) => ServiceRecord(
        id: '$type$date',
        type: type,
        title: type.label,
        date: date,
        km: 90000,
        cost: 3200,
        addedByOwnerId: 'me',
        createdAt: date,
      );

  Expense expense(ExpenseType type, DateTime date) => Expense(
        id: '$type$date',
        type: type,
        title: type.label,
        date: date,
        amount: 3200,
        createdAt: date,
      );

  group('the date the app offers to start from', () {
    test('a year after the last recorded premium', () {
      final out = InsuranceRenewal.suggest(
        services: [service(ServiceType.insurance, DateTime(2026, 4, 1))],
        expenses: const [],
        now: now,
      );
      expect(out, DateTime(2026, 4, 1).add(InsuranceRenewal.term));
    });

    test('a premium recorded as an expense counts too', () {
      // Owners log the same payment in either place depending on which screen
      // they happened to be on. Reading only one of them would leave half of
      // them with no suggestion for no reason they could see.
      final out = InsuranceRenewal.suggest(
        services: const [],
        expenses: [expense(ExpenseType.insurance, DateTime(2026, 4, 1))],
        now: now,
      );
      expect(out, isNotNull);
    });

    test('the most recent premium wins', () {
      final out = InsuranceRenewal.suggest(
        services: [
          service(ServiceType.insurance, DateTime(2024, 4, 1)),
          service(ServiceType.insurance, DateTime(2026, 4, 1)),
        ],
        expenses: const [],
        now: now,
      );
      expect(out!.year, 2027);
    });

    test('nothing recorded means no guess, not a wrong one', () {
      expect(
        InsuranceRenewal.suggest(
          services: [service(ServiceType.routine, DateTime(2026, 4, 1))],
          expenses: const [],
          now: now,
        ),
        isNull,
      );
    });

    test('a guess that has already passed is withheld', () {
      // "Renew by a date three months ago" teaches the reader the suggestion
      // is not to be trusted, which costs more than the empty field it was
      // meant to save them.
      expect(
        InsuranceRenewal.suggest(
          services: [service(ServiceType.insurance, DateTime(2024, 1, 1))],
          expenses: const [],
          now: now,
        ),
        isNull,
      );
    });
  });

  group('how early it starts warning', () {
    VehicleReminder reminder(ReminderType type, int inDays) => VehicleReminder(
          id: 'r',
          type: type,
          title: type.label,
          dueDate: DateTime.now().add(Duration(days: inDays)),
          isDone: false,
          source: ReminderSource.manual,
          createdAt: DateTime.now(),
        );

    test('insurance gets longer notice than everything else', () {
      // A test is an appointment you book; insurance renewal is a market you
      // shop. Three weeks is enough notice to comply and not enough to
      // negotiate before the policy rolls over at whatever the insurer chose.
      expect(reminder(ReminderType.insurance, 30).isDueSoon, isTrue);
      expect(reminder(ReminderType.timingBelt, 30).isDueSoon, isFalse,
          reason: 'everything else still uses three weeks');
    });

    test('and it does stop somewhere', () {
      expect(reminder(ReminderType.insurance, 200).isDueSoon, isFalse);
      expect(InsuranceRenewal.leadDays, greaterThan(21));
    });

    test('a reminder already marked done never resurfaces', () {
      final done = VehicleReminder(
        id: 'r',
        type: ReminderType.insurance,
        title: 'ביטוח',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        isDone: true,
        source: ReminderSource.manual,
        createdAt: DateTime.now(),
      );
      expect(done.isDueSoon, isFalse);
    });
  });

  test('the app never invents the date by itself', () {
    // The rule the reminders were built on: only the test reminder is created
    // automatically, because the licence expiry is the one date that is a fact
    // from the registry. An insurance policy is a private contract and no
    // dataset knows when it ends, so anything the app produces is a suggestion
    // the owner confirms — never a reminder written on their behalf.
    final prompt =
        File('lib/presentation/widgets/vehicle/insurance_prompt.dart')
            .readAsStringSync();
    expect(prompt.contains('addReminder'), isFalse,
        reason: 'the prompt asks; it does not write');
    expect(prompt, contains('AddReminderSheet.show'));

    final util =
        File('lib/core/utils/insurance_renewal.dart').readAsStringSync();
    expect(util.contains('addReminder'), isFalse);
    expect(util, contains('ReminderType.test'),
        reason: 'and it names the rule it is deferring to');
  });

  test('the prompt does not promise a notification the app cannot send', () {
    // There is no server and no background push on the Spark plan — the recall
    // check runs when the owner opens their garage, and the code says as much
    // out loud. A reminder that promised to reach a closed phone would be the
    // app claiming to watch over somebody while it is not running.
    final prompt =
        File('lib/presentation/widgets/vehicle/insurance_prompt.dart')
            .readAsStringSync();
    for (final banned in const ['נשלח לכם', 'התראה לטלפון', 'הודעת push']) {
      expect(prompt.contains(banned), isFalse, reason: banned);
    }
  });
}
