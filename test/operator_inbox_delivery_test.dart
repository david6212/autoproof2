import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/data/repositories/operator_inbox_repository.dart';
import 'package:bonnetcheck/presentation/providers/operator_inbox_provider.dart';
import 'package:bonnetcheck/presentation/widgets/operator_inbox_card.dart';

/// The inbox was empty by construction, and no test noticed for its whole life.
///
/// The query asked the server for `handledAt == null`, and none of the three
/// writers ever wrote the field. Firestore does not index a document for a
/// field it does not have, so a report **missing** `handledAt` is not "null"
/// to the index — it simply is not there, and is never returned. Every report
/// filed since the inbox shipped was written, was readable by the operator,
/// and was invisible in the only surface built to show it.
///
/// `test/operator_inbox_test.dart` asserted the query's source text, which is
/// exactly the sentence that caused the bug, so it passed. These tests run the
/// real code instead.
///
/// Why no `fake_cloud_firestore` here: that package answers `isNull: true` by
/// reading the field and comparing to null, so a missing key matches and the
/// fake returns the document. It would have shown the inbox working while
/// production showed nothing — a worse outcome than no test.
void main() {
  group('a report with no handledAt key is an open report', () {
    // This is the document shape all three writers produced: no `handledAt`
    // anywhere in the map. It must reach the operator.
    final filed = {
      'r-old': {'carId': 'c1', 'createdAt': null},
      'r-new': {'carId': 'c2', 'createdAt': null},
    };

    test('it is carried through, not filtered out', () {
      final open = OperatorInboxRepository.openOnly(InboxKind.noteReport, filed);
      expect(open.map((i) => i.id), ['r-old', 'r-new']);
    });

    test('an answered one is filtered out, and only that one', () {
      final open = OperatorInboxRepository.openOnly(InboxKind.noteReport, {
        ...filed,
        'r-done': {'carId': 'c3', 'handledAt': DateTime(2026, 9, 1)},
      });
      expect(open.map((i) => i.id), ['r-old', 'r-new']);
    });

    test('an explicit null handledAt is still open', () {
      // What the writers produce from now on. It must mean the same thing as
      // the absent key, or the backfill question comes back.
      final open = OperatorInboxRepository.openOnly(InboxKind.correction, {
        'r-1': {'handledAt': null},
      });
      expect(open.map((i) => i.id), ['r-1']);
    });
  });

  group('every report is written saying nobody has answered it', () {
    test('the field is present, and null', () {
      final data = unansweredReport({'carId': 'c1'});
      expect(data.containsKey('handledAt'), isTrue,
          reason: 'an absent key is invisible to the inbox');
      expect(data['handledAt'], isNull);
    });

    test('and the report it wraps is untouched', () {
      expect(unansweredReport({'carId': 'c1', 'note': 'x'}),
          containsPair('carId', 'c1'));
      expect(unansweredReport({'carId': 'c1', 'note': 'x'}),
          containsPair('note', 'x'));
    });

    test('all three writers go through it', () {
      // The one thing here a pure function cannot prove: that the map handed
      // to `add()`/`set()` is the wrapped one. `FirebaseFirestore` cannot be
      // subclassed in a test in this repo, so the seam is read from source —
      // deliberately, and only for the call site, not for the behaviour.
      final car = File('lib/data/repositories/car_repository.dart')
          .readAsStringSync();
      final place = File('lib/data/repositories/place_repository.dart')
          .readAsStringSync();
      expect("$car$place".split('unansweredReport(').length - 1, 3,
          reason: 'note_reports, data_corrections and review_reports');
    });
  });

  test('the inbox no longer asks the server a question about a missing field', () {
    // Server-side `where('handledAt', isNull: true)` is what hid every report
    // already filed. The bound stays — this runs on a plan with 50,000 reads
    // a day for the whole app.
    //
    // Comments are stripped first, and that is not a detail: the old test read
    // the whole file for this exact string, so it would have gone green again
    // on the sentence in `watch` that explains why the clause was removed.
    final code = File('lib/data/repositories/operator_inbox_repository.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains("where('handledAt'"), isFalse,
        reason: 'documents written before the fix carry no such field');
    expect(code, contains("orderBy('createdAt')"));
    expect(code, contains('.limit('));
  });

  testWidgets('and it arrives on the screen the operator opens', (tester) async {
    // A filter that returns the right list is not the fix. The fix is a
    // report the operator can see, and this project has shipped code that was
    // never rendered — so the document shape goes in one end and the card is
    // read off the other.
    final filed = OperatorInboxRepository.openOnly(InboxKind.noteReport, {
      'r-1': {'carId': 'c1', 'createdAt': DateTime(2026, 9, 1)},
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOperatorProvider.overrideWithValue(true),
          operatorInboxProvider.overrideWith((ref) => Stream.value(filed)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(child: OperatorInboxCard()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('פניות ממתינות: 1'), findsOneWidget);
    expect(find.text('אין פניות ממתינות'), findsNothing,
        reason: 'this is the sentence the operator saw for the whole time '
            'reports were arriving');
    expect(find.text('דיווח על הערה'), findsOneWidget);
  });
}
