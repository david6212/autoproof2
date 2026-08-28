import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/assistant/car_assistant.dart';
import 'package:bonnetcheck/data/models/service_record.dart';

/// The on-device assistant.
///
/// It costs nothing, needs no network and cannot hallucinate — it is a keyword
/// table over data the app already holds. These tests care about two things:
/// that it answers the questions people actually ask, and that it never once
/// crosses from reporting a record into appraising the car.
void main() {
  final now = DateTime(2026, 8, 27);

  ServiceRecord service({
    required ServiceType type,
    required String title,
    required DateTime date,
    int km = 90000,
    int cost = 1200,
    String? garage,
  }) =>
      ServiceRecord(
        id: title,
        type: type,
        title: title,
        date: date,
        km: km,
        cost: cost,
        garageName: garage,
        addedByOwnerId: 'me',
        createdAt: date,
      );

  AssistantContext ctx({
    List<ServiceRecord> services = const [],
    int openRecalls = 0,
    bool govReachable = true,
  }) =>
      AssistantContext(
        services: services,
        openRecalls: openRecalls,
        govReachable: govReachable,
        now: now,
      );

  group('it declines rather than guesses', () {
    test('an unrecognised question returns null', () {
      // The caller can then fall through to something else. A confident wrong
      // answer is the one behaviour that would make this worse than nothing.
      expect(CarAssistant.answer('מה דעתך על הרכב הזה', ctx()), isNull);
      expect(CarAssistant.answer('כדאי לי למכור', ctx()), isNull);
    });

    test('an empty question returns null', () {
      expect(CarAssistant.answer('   ', ctx()), isNull);
    });
  });

  group('service history', () {
    final services = [
      service(
          type: ServiceType.tires,
          title: 'החלפת צמיגים',
          date: DateTime(2026, 3, 4),
          km: 88000,
          garage: 'מוסך הכרמל'),
      service(
          type: ServiceType.routine,
          title: 'טיפול 90,000',
          date: DateTime(2026, 6, 1),
          km: 90500,
          cost: 2400),
    ];

    test('answers when tyres were changed, with the garage', () {
      final a = CarAssistant.answer('מתי החלפתי צמיגים?', ctx(services: services));
      expect(a, isNotNull);
      expect(a!.text, contains('04/03/2026'));
      expect(a.text, contains('88,000'));
      expect(a.text, contains('מוסך הכרמל'));
      expect(a.source, CarAssistant.sourceRecords);
    });

    test('final letters do not defeat it', () {
      // "צמיגים" ends in a final mem; the keyword is stemmed. Without folding,
      // the single most likely phrasing of the question would miss.
      for (final q in const ['צמיגים', 'צמיג', 'החלפתי צמיגים']) {
        expect(CarAssistant.answer(q, ctx(services: services)), isNotNull,
            reason: q);
      }
    });

    test('says plainly when a kind of service was never recorded', () {
      final a = CarAssistant.answer('מתי החלפתי בלמים?', ctx(services: services));
      expect(a!.text, contains('לא רשמתם'));
    });
  });

  group('money', () {
    final services = [
      service(
          type: ServiceType.routine,
          title: 'טיפול',
          date: DateTime(2026, 6, 1),
          cost: 2400),
      service(
          type: ServiceType.repair,
          title: 'תיקון',
          date: DateTime(2025, 6, 1),
          cost: 1000),
    ];

    test('totals everything by default', () {
      final a = CarAssistant.answer('כמה הוצאתי על הרכב', ctx(services: services));
      expect(a!.text, contains('3,400'));
    });

    test('"השנה" narrows it to this year', () {
      final a = CarAssistant.answer('כמה הוצאתי השנה', ctx(services: services));
      expect(a!.text, contains('2,400'));
      expect(a.text, contains('השנה'));
    });
  });

  group('recalls', () {
    test('an open recall is reported with what to do', () {
      final a = CarAssistant.answer('יש ריקול?', ctx(openRecalls: 2));
      expect(a!.text, contains('2'));
      expect(a.text, contains('ללא עלות'));
    });

    test('none found is worded as the dataset being empty, not as safety', () {
      // The single most important sentence in this file. "No recalls listed"
      // is a fact about a dataset; "the car is fine" is a claim about a car,
      // and the app is not entitled to make it.
      final a = CarAssistant.answer('יש ריקול?', ctx());
      expect(a!.text, contains('לא רשומות'));
      for (final forbidden in const ['תקין', 'בסדר', 'בטוח', 'אין בעיה']) {
        expect(a.text.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('unreachable registry is not reported as a clean result', () {
      // "We could not check" and "we checked and found nothing" are different
      // answers, and collapsing them is how an app starts lying by accident.
      final a =
          CarAssistant.answer('יש ריקול?', ctx(govReachable: false));
      expect(a!.text, contains('לא בדקנו'));
      expect(a.text, contains('זה לא אומר שאין'));
    });
  });

  test('every answer names where the fact came from', () {
    for (final q in const ['יש ריקול', 'כמה הוצאתי', 'מתי החלפתי צמיגים']) {
      final a = CarAssistant.answer(q, ctx());
      expect(a?.source, isNotNull, reason: q);
      expect(a!.source, isNotEmpty, reason: q);
    }
  });

  test('the assistant contains no path to an opinion about a car', () {
    // A source scan, because the risk is a future contributor adding a helpful
    // sentence rather than an existing bug. This surface is the easiest place
    // in the app to break the claims rule: an answer phrased as advice reads
    // as advice.
    final source =
        File('lib/core/assistant/car_assistant.dart').readAsStringSync();
    for (final banned in const [
      'שווה לקנות',
      'הרכב תקין',
      'מומלץ לקנות',
      'במצב טוב',
      'לא כדאי',
    ]) {
      expect(source.contains(banned), isFalse, reason: banned);
    }
  });
}
