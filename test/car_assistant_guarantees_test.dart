import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/assistant/car_assistant.dart';
import 'package:bonnetcheck/data/models/expense.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/data/models/service_record.dart';

/// The three promises the assistant makes, as opposed to the answers it gives.
///
/// `car_assistant_test.dart` next door proves it answers the questions people
/// ask. This file proves the promises around those answers, each of which is
/// invisible in normal use and would stay invisible for months if it broke:
///
/// 1. **It runs on the device.** The card tells the reader in so many words
///    that no question is sent anywhere. That is a privacy claim, and a claim
///    is only worth what enforces it.
/// 2. **It reports records and never appraises a car.** This is the single
///    surface in the app where breaking the claims rule would be easiest and
///    would read most naturally, because a sentence in an answer box reads as
///    advice whether or not it was meant as one.
/// 3. **A gap in the registry is reported as a gap.** "We could not check" and
///    "we checked and found nothing" are different answers, and an assistant
///    that collapses them lies without anyone writing a lie.
void main() {
  final now = DateTime(2026, 8, 27);

  GovData gov({DateTime? licenseExpiry = const _KeepDefault._()}) => GovData(
        plate: '12345678',
        make: 'טויוטה',
        commercialName: 'קורולה',
        model: 'ZRE210',
        year: 2019,
        color: 'לבן',
        fuelType: 'בנזין',
        ownershipType: 'פרטי',
        trim: 'HYBRID',
        lastTestDate: DateTime(2026, 3, 2),
        licenseExpiry: identical(licenseExpiry, const _KeepDefault._())
            ? DateTime(2027, 3, 1)
            : licenseExpiry,
        safetyRating: '7',
        chassis: 'JTDBR32E900123456',
      );

  ServiceRecord service({
    ServiceType type = ServiceType.routine,
    String title = 'טיפול 90,000',
    DateTime? date,
    int km = 90500,
    int cost = 1200,
  }) =>
      ServiceRecord(
        id: '$title$km',
        type: type,
        title: title,
        date: date ?? DateTime(2026, 6, 1),
        km: km,
        cost: cost,
        addedByOwnerId: 'me',
        createdAt: date ?? DateTime(2026, 6, 1),
      );

  AssistantContext ctx({
    GovData? govData,
    List<ServiceRecord> services = const [],
    List<Expense> expenses = const [],
    int openRecalls = 0,
    bool recallsChecked = true,
    bool recordsLoaded = true,
  }) =>
      AssistantContext(
        gov: govData,
        services: services,
        expenses: expenses,
        openRecalls: openRecalls,
        recallsChecked: recallsChecked,
        recordsLoaded: recordsLoaded,
        now: now,
      );

  // ---------------------------------------------------------------------
  // 1. On the device
  // ---------------------------------------------------------------------

  group('nothing the reader types leaves the phone', () {
    test('answering is synchronous, so it cannot have waited for anything', () {
      // Structural, and stronger than any string scan: a function that returns
      // its answer rather than a Future has no way to have talked to a network
      // or to Firestore on the way. If someone ever needs `async` here, this
      // line stops compiling and the privacy claim on the card has to be
      // revisited in the same commit.
      const AssistantAnswer? Function(String, AssistantContext) answer =
          CarAssistant.answer;

      expect(answer('יש ריקול', ctx()), isA<AssistantAnswer>());
      expect(answer('יש ריקול', ctx()), isNot(isA<Future>()));
    });

    test('the assistant imports nothing — not a package, not even Flutter', () {
      // It reaches only for three model classes and a date formatter, all of
      // which are import-free themselves. There is therefore no client, no
      // key, and nothing to bill: the feature is free forever, which is why it
      // could be built at all. An import line is the first thing that would
      // change if that stopped being true.
      final source =
          File('lib/core/assistant/car_assistant.dart').readAsStringSync();
      final imports = const LineSplitter()
          .convert(source)
          .where((l) => l.trimLeft().startsWith('import '))
          .toList();

      expect(imports, isNotEmpty);
      for (final line in imports) {
        expect(line.contains('package:'), isFalse, reason: line);
        expect(line.contains('dart:'), isFalse, reason: line);
      }
    });

    test('the card neither transmits the question nor records it', () {
      // The card prints "שום שאלה לא נשלחת לשום מקום" to the reader. The two
      // ways that promise dies are a network call and an analytics event, and
      // the second is the likelier one — logging what people ask is the most
      // natural "harmless" instrumentation anybody would add, and it would
      // ship a stranger's questions about their own car to Firebase.
      final card = File(
        'lib/presentation/widgets/vehicle/car_assistant_card.dart',
      ).readAsStringSync();

      expect(card.contains('שום שאלה לא נשלחת לשום מקום'), isTrue,
          reason: 'the promise itself must stay on the card');
      for (final transport in const [
        'package:http',
        'cloud_firestore',
        'FirebaseFirestore',
        'firebase_analytics',
        'Analytics',
        'logEvent',
        'HttpClient',
        'Uri.parse',
      ]) {
        expect(card.contains(transport), isFalse, reason: transport);
      }
    });
  });

  // ---------------------------------------------------------------------
  // 2. Records, never a verdict
  // ---------------------------------------------------------------------

  group('it reports records and never appraises the car', () {
    /// Every answer the assistant can produce across the states that matter.
    List<AssistantAnswer> everyAnswer() {
      final contexts = <AssistantContext>[
        ctx(govData: gov()),
        ctx(govData: gov(licenseExpiry: DateTime(2026, 1, 1))),
        ctx(govData: gov(), openRecalls: 0),
        ctx(govData: gov(), openRecalls: 3),
        ctx(recallsChecked: false, openRecalls: 3),
        ctx(
          govData: gov(),
          services: [
            service(),
            service(type: ServiceType.tires, title: 'צמיגים', km: 88000),
          ],
          expenses: [
            Expense(
              id: 'e1',
              type: ExpenseType.fuel,
              date: DateTime(2026, 7, 1),
              amount: 300,
              km: 91000,
              createdAt: DateTime(2026, 7, 1),
            ),
          ],
        ),
      ];
      const questions = [
        'מתי הטסט הבא',
        'יש ריקול',
        'כמה הוצאתי',
        'כמה הוצאתי השנה',
        'מתי החלפתי צמיגים',
        'מתי טיפול אחרון',
        'כמה קילומטר',
        'איזה רכב זה',
      ];

      return [
        for (final c in contexts)
          for (final q in questions)
            if (CarAssistant.answer(q, c) case final a?) a,
      ];
    }

    test('no answer, in any state, contains a judgement about the car', () {
      // §6.6, applied where it is easiest to lose. The assistant may say what
      // a record says. It may not say what the record means for the car,
      // because the moment it does, the app has appraised a vehicle it has
      // never seen — and the reader has no way to tell the two apart when both
      // arrive in the same box, in the same voice.
      final answers = everyAnswer();
      expect(answers.length, greaterThan(20),
          reason: 'the sweep has to actually reach the intents');

      for (final a in answers) {
        for (final verdict in const [
          'תקין',
          'מאושר',
          'אושר',
          'מומלץ',
          'כדאי',
          'שווה',
          'בטוח',
          'אמין',
          'מצוין',
          'בעייתי',
          'סיכון',
          'ציון',
          'דירוג',
          'במצב טוב',
        ]) {
          expect(a.text.contains(verdict), isFalse,
              reason: '"$verdict" in: ${a.text}');
        }
      }
    });

    test('nothing shouts, and every answer says where it came from', () {
      // An exclamation mark turns a record into an alarm and the reader cannot
      // un-hear it. An unattributed sentence asks to be believed, and this app
      // shows its work instead.
      for (final a in everyAnswer()) {
        expect(a.text.contains('!'), isFalse, reason: a.text);
        expect(a.source, isNotEmpty, reason: a.text);
      }
    });

    test('a question fishing for advice still gets a record back', () {
      // "Is a car with 200,000 km worth buying" hits the mileage intent. The
      // honest reply is the reading the owner themselves logged — not an
      // opinion on the purchase, which is the answer the phrasing invites and
      // the one the app is not entitled to give.
      final a = CarAssistant.answer(
        'כדאי לקנות רכב עם 200,000 קילומטר?',
        ctx(services: [service(km: 90500)]),
      );

      expect(a, isNotNull);
      expect(a!.text, contains('90,500'));
      expect(a.source, CarAssistant.sourceRecords);
    });

    test('a valid licence is a date, not a clean bill of health', () {
      // The most tempting rewrite in the file: "הרישיון בתוקף, הכול בסדר".
      // A licence in date says the fee was paid and a test was passed on one
      // morning. It says nothing about the car today, and an answer that
      // rounds it up to reassurance is the app certifying a vehicle.
      final a = CarAssistant.answer('מתי הטסט הבא?', ctx(govData: gov()));

      expect(a, isNotNull);
      expect(a!.text, contains('01/03/2027'));
      expect(a.source, CarAssistant.sourceRegistry);
      for (final reassurance in const ['בסדר', 'הכול תקין', 'אין מה לדאוג']) {
        expect(a.text.contains(reassurance), isFalse, reason: reassurance);
      }
    });

    test('the card renders the answer and adds no opinion of its own', () {
      // The scan next door covers the logic file. The verdict could just as
      // easily be added one layer up, as a friendly line under the answer box,
      // and no test would have noticed.
      final card = File(
        'lib/presentation/widgets/vehicle/car_assistant_card.dart',
      ).readAsStringSync();

      for (final verdict in const [
        'תקין',
        'מומלץ',
        'שווה לקנות',
        'ציון',
        'דירוג',
        'במצב טוב',
      ]) {
        expect(card.contains(verdict), isFalse, reason: verdict);
      }
    });
  });

  // ---------------------------------------------------------------------
  // 3. A gap is reported as a gap
  // ---------------------------------------------------------------------

  group('what it could not check, rather than a guess', () {
    test('an unreachable registry is not answered with a date', () {
      // Only the recall intent was pinned for this before. The licence intent
      // has the same trapdoor and is asked far more often: silence, or a
      // remembered date, would both read as "your licence is fine".
      // No stored registry copy for this car. There is no live lookup to
      // fail — the assistant never makes one — so what the reader is told is
      // that we have nothing, not that something went wrong just now.
      final a = CarAssistant.answer('מתי הטסט הבא?', ctx());

      expect(a, isNotNull);
      expect(a!.text, contains('אין לנו עותק שמור'));
      expect(RegExp(r'\d').hasMatch(a.text), isFalse,
          reason: 'no number may appear in an answer we could not look up');
      expect(a.source, isNot(CarAssistant.sourceRegistry),
          reason: 'a registry we never reached cannot be cited as the source');
    });

    test('an answer about the licence is never phrased as a live check', () {
      // This replaces a test that pinned `govReachable: false` alongside a
      // present record — "the lookup failed but stale data is lying around".
      // That state no longer exists and could not be represented honestly:
      // the assistant makes no lookup at all, so a stored record IS the
      // answer, and the one flag covering five datasets was itself the bug.
      //
      // What still has to hold is the wording. An answer built from a copy
      // saved months ago must not describe itself as something that happened
      // now, because "just now" invites a retry that would change nothing.
      final a = CarAssistant.answer(
        'מתי פג תוקף הרישיון?',
        ctx(govData: gov()),
      );

      expect(a, isNotNull);
      for (final live in const ['כרגע', 'לא הצלחנו להגיע', 'לא זמין']) {
        expect(a!.text.contains(live), isFalse, reason: live);
      }
    });

    test('a recall count is not reported when the recall dataset was silent',
        () {
      // Three open recalls in the context and no dataset behind them. Printing
      // the number would be inventing a check; printing nothing would read as
      // a car with no recalls. It says neither.
      final a = CarAssistant.answer(
        'יש ריקול?',
        ctx(openRecalls: 3, recallsChecked: false),
      );

      expect(a!.text, contains('לא בדקנו'));
      expect(a.text, contains('זה לא אומר שאין'));
      expect(a.text.contains('3'), isFalse);
    });

    test('a registry record with no expiry date produces no date', () {
      // The registry answering *without* the field is different again from the
      // registry not answering. There is nothing honest to say here, so the
      // assistant says nothing and the card falls back to "I did not
      // understand" — blunter than it should be, but never invented. What this
      // pins is the half that matters: no date is conjured out of a null.
      expect(
        CarAssistant.answer(
          'מתי פג תוקף הרישיון?',
          ctx(govData: gov(licenseExpiry: null)),
        ),
        isNull,
      );
    });

    test('with no registry record the car is not described from blanks', () {
      // `'${gov.make} ${gov.model}'` on a null-ish record would happily render
      // ", , סוג דלק" and look like a fact. The intent declines instead.
      expect(CarAssistant.answer('איזה רכב זה?', ctx()), isNull);

      final a = CarAssistant.answer('איזה רכב זה?', ctx(govData: gov()));
      expect(a!.text, contains('טויוטה'));
      expect(a.source, CarAssistant.sourceRegistry);
    });

    test('an intent with nothing to say hands over instead of answering zero',
        () {
      // The fall-through in `answer`. With no logged readings the mileage
      // intent must not reply "0 ק\"מ" — a reading nobody entered, stated as
      // one they did — so it declines and the car-facts intent takes the same
      // question.
      const question = 'כמה קילומטר יש לדגם הזה?';

      final withoutRecords =
          CarAssistant.answer(question, ctx(govData: gov()));
      expect(withoutRecords!.text, contains('טויוטה'));
      expect(withoutRecords.text.contains('0 ק"מ'), isFalse);

      final withRecords = CarAssistant.answer(
        question,
        ctx(govData: gov(), services: [service(km: 90500)]),
      );
      expect(withRecords!.text, contains('90,500'));
    });

    test('no expenses is stated as no records, never as a car that cost 0', () {
      // "0 ₪" is a claim about the car — that it has been cheap to run. "You
      // have not logged anything" is a claim about the app, which is the only
      // one of the two we can make.
      final a = CarAssistant.answer('כמה הוצאתי על הרכב', ctx());

      expect(a!.text, contains('עוד לא רשמתם'));
      expect(a.text.contains('0 ₪'), isFalse);
      expect(a.source, CarAssistant.sourceExpenses);
    });
  });
}

/// Sentinel so a test can pass an explicit `null` expiry and still tell it
/// apart from "leave the default alone".
class _KeepDefault implements DateTime {
  const _KeepDefault._();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
