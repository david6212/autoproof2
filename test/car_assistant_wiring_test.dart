import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/models/expense.dart';
import 'package:bonnetcheck/data/models/service_record.dart';
import 'package:bonnetcheck/data/models/vehicle.dart';
import 'package:bonnetcheck/presentation/providers/vehicle_provider.dart';
import 'package:bonnetcheck/presentation/widgets/vehicle/car_assistant_card.dart';

/// The assistant as its only caller actually builds it.
///
/// ## Why this file exists
///
/// `car_assistant_test.dart` and `car_assistant_guarantees_test.dart` both
/// hand [CarAssistant] a context they built themselves, and both are green.
/// They are also blind by construction: a context assembled in a test can
/// never show that the one place in `lib/` that assembles a real one fills it
/// in wrong.
///
/// It does. `car_assistant_card.dart` builds `AssistantContext` from the
/// vehicle's registry snapshot and its service and expense records, and never
/// passes `openRecalls` — which defaults to `0` (`car_assistant.dart:17`). So
/// the recall intent takes the "the dataset listed none" branch for **every
/// car in production**, including one whose open recalls the app already
/// knows about: `vehicle_detail_screen.dart:693` paints a recall banner from
/// `vehicle.openRecallCount`, and thirty-six lines later, at :729, mounts the
/// card that tells the same owner on the same screen that nothing is listed.
///
/// Which is not merely a wrong answer. "לא רשומות קריאות פתוחות" attributed
/// to "לפי מרשם הרכב" is the app reporting a check it did not run as a check
/// that came back clean — §6.6, on the surface where it is least visible,
/// because the owner has no way to see that the number never arrived.
///
/// These tests are therefore written from the symptom, at the widget, in the
/// only place the defect is real.
void main() {
  /// A registry snapshot as the seller's app stored it, in the shape
  /// `GovData.fromSnapshot` reads back.
  Map<String, dynamic> snapshot({
    List<Map<String, String>> recalls = const [],
    List<String> missing = const [],
  }) =>
      {
        'make': 'טויוטה',
        'commercialName': 'קורולה',
        'model': 'ZRE210',
        'year': 2019,
        'color': 'לבן',
        'fuelType': 'בנזין',
        'licenseExpiry': DateTime(2027, 3, 1).toIso8601String(),
        'recalls': recalls,
        'missing': missing,
      };

  Vehicle vehicle({
    Map<String, dynamic>? gov,
    int openRecallCount = 0,
  }) =>
      Vehicle(
        id: 'v1',
        plate: '12345678',
        ownerId: 'me',
        govSnapshot: gov,
        openRecallCount: openRecallCount,
        createdAt: DateTime(2026, 1, 1),
      );

  Widget host(Vehicle v) => ProviderScope(
        overrides: [
          // Not decoration: reading the real providers would build the
          // repositories, and a repository here reaches Firebase and the test
          // dies before the card is ever asked anything.
          vehicleServicesProvider
              .overrideWith((ref, id) => Stream.value(const <ServiceRecord>[])),
          vehicleExpensesProvider
              .overrideWith((ref, id) => Stream.value(const <Expense>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: CarAssistantCard(vehicle: v),
              ),
            ),
          ),
        ),
      );

  /// Types a question and submits it the way a thumb does.
  Future<String> ask(WidgetTester t, String question) async {
    await t.enterText(find.byType(TextField), question);
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();

    return t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join('\n');
  }

  testWidgets('a car with open recalls is not told it has none', (t) async {
    // The whole defect in one screen. Two recalls are on the snapshot the
    // card reads and on the vehicle field the banner above it draws from, and
    // the assistant still reports an empty register — because the count never
    // reaches it.
    await t.pumpWidget(host(vehicle(
      gov: snapshot(recalls: const [
        {'system': 'בלמים', 'description': 'החלפת צילינדר', 'date': '2025-04-01'},
        {'system': 'כריות אוויר', 'description': 'מנפח', 'date': '2025-09-02'},
      ]),
      openRecallCount: 2,
    )));

    final shown = await ask(t, 'יש ריקול?');

    expect(shown.contains('לא נרשמו קריאות פתוחות'), isFalse,
        reason: 'the app holds two open recalls for this car: $shown');
    expect(shown, contains('2'));
  });

  testWidgets('a recall dataset that never answered is not reported as empty',
      (t) async {
    // The snapshot exists, so the card says the registry is reachable — but
    // `missing: ['recalls']` records that this one endpoint did not answer
    // when the snapshot was taken. An empty recall list then means "we do not
    // know", and saying "none are listed" over it is the substitution
    // `missingDatasets` was built to refuse.
    await t.pumpWidget(host(vehicle(gov: snapshot(missing: const ['recalls']))));

    final shown = await ask(t, 'יש ריקול?');

    expect(shown.contains('לא נרשמו קריאות פתוחות'), isFalse,
        reason: 'the recall dataset was never reached: $shown');
  });

  testWidgets('a car the register really did answer about still gets an answer',
      (t) async {
    // The other edge, so the two above cannot be satisfied by making the
    // recall intent silent. When the dataset answered and listed nothing,
    // saying so is honest and is the answer the owner asked for.
    await t.pumpWidget(host(vehicle(gov: snapshot())));

    expect(await ask(t, 'יש ריקול?'), contains('לא נרשמו קריאות פתוחות'));
  });

  /// Overflows surface as caught framework exceptions, not as failures, so a
  /// test that does not go looking for them passes over a clipped layout.
  List<Object> overflowErrors() {
    final found = <Object>[];
    while (true) {
      final e = TestWidgetsFlutterBinding.instance.takeException();
      if (e == null) break;
      found.add(e);
    }
    return found;
  }

  group('it still fits when the system text is large', () {
    // The fifth screen to clip. Four others were found at 1.5x in one pass in
    // August, and this card's hand-rolled header repeated the mistake they
    // were fixed for: a Row with an unbounded Text and no Expanded. Measured
    // at 5px over at 1.5x and 95px over at 2.0x before `AppSectionCard`
    // replaced it.
    //
    // 1.5 and 2.0 are both inside what Android and iOS offer in Settings.
    // Nobody has to do anything unusual to reach them.
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('nothing overflows at ${scale}x', (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        await t.pumpWidget(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: host(vehicle(gov: snapshot())),
        ));
        await t.pumpAndSettle();

        expect(overflowErrors(), isEmpty,
            reason: 'RenderFlex overflow at ${scale}x');
      });
    }
  });

  testWidgets('a question it cannot answer is declined out loud', (t) async {
    // Silence is not neutral. An empty box after "is this car worth buying"
    // reads as "nothing to report", which is the answer the app is least
    // entitled to give — so the refusal has to be visible, and no answer box
    // may be drawn beside it.
    await t.pumpWidget(host(vehicle(gov: snapshot())));

    final shown = await ask(t, 'כדאי לקנות את הרכב הזה?');

    expect(shown, contains('לא הבנתי את השאלה'));
    expect(shown.contains('לפי מרשם הרכב'), isFalse,
        reason: 'nothing was looked up, so nothing may be attributed');
  });

  test('no caller may leave the recall count at its default', () {
    // The structural half, and the general lesson of this file: an optional
    // parameter with a plausible default is invisible at the call site, and a
    // unit test that builds the context itself will never look there. Every
    // production assembly of an `AssistantContext` has to say what it knows
    // about recalls — including, explicitly, that it knows nothing.
    final sites = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final src = file.readAsStringSync();
      final at = src.indexOf('AssistantContext(');
      if (at < 0) continue;
      // The declaration itself, not a call.
      if (src.contains('class AssistantContext')) continue;
      if (!src.substring(at).contains('openRecalls:')) sites.add(file.path);
    }

    expect(sites, isEmpty,
        reason: 'these build an assistant that cannot see a recall');
  });
}
