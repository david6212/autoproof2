import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/theme/app_palette.dart';
import 'package:bonnetcheck/data/models/vehicle.dart';
import 'package:bonnetcheck/presentation/widgets/documented_progress_meter.dart';

/// Documenting a car has no finish line.
///
/// David's point, and it is the product's point: people keep cars for years,
/// and the whole value of the passport is that those years are on record. The
/// badge needs a minimum — three records over six months, so it cannot be
/// earned in one evening before a sale — but the minimum was reading as a
/// target: the meter counted to 3 and then vanished, which told an owner that
/// three was all the app wanted.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('nothing caps how much can be documented', () {
    test('not in the code that writes a record', () {
      // No max, no "you already have enough", no pagination that silently
      // drops the oldest. If one is ever added, it belongs in a product
      // decision and not in a repository.
      final repo = File('lib/data/repositories/service_repository.dart')
          .readAsStringSync();
      expect(repo.contains('.limit('), isFalse);
      expect(repo.contains('documentedMinRecords'), isFalse,
          reason: 'the badge threshold has no business gating a write');
    });

    test('and not in the rules', () {
      final rules = File('firestore.rules').readAsStringSync();
      final services = rules.substring(rules.indexOf('match /services/{serviceId}'));
      final block = services.substring(0, services.indexOf('\n      }'));
      expect(block.contains('serviceCount <'), isFalse);
      expect(block, contains('allow create'));
    });

    test('and the timeline shows every record it is given', () {
      final timeline = File('lib/presentation/widgets/service_timeline.dart')
          .readAsStringSync();
      expect(timeline.contains('.take('), isFalse);
    });
  });

  group('the span is stated in the largest unit that is still true', () {

    for (final (months, expected) in [
      (0, ''),
      (1, 'חודש'),
      (7, '7 חודשים'),
      (12, 'שנה'),
      (23, 'שנה'),
      (48, '4 שנים'),
      (96, '8 שנים'),
    ]) {
      test('$months months reads "$expected"', () {
        final progress = DocumentedProgress(records: 5, months: months);
        expect(progress.spanLabel, expected);
      });
    }

    test('eight years of receipts does not read as 96 months', () {
      const progress = DocumentedProgress(records: 24, months: 96);
      expect(progress.depthLabel, '24 רשומות · 8 שנים');
    });

    test('one record is counted in words, like everywhere else', () {
      expect(const DocumentedProgress(records: 1, months: 0).depthLabel,
          'רשומה אחת');
    });
  });

  group('the meter after the badge is earned', () {
    testWidgets('keeps counting instead of disappearing', (tester) async {
      const earned = DocumentedProgress(records: 12, months: 48);
      expect(earned.earned, isTrue);

      await tester.pumpWidget(
        host(const DocumentedProgressMeter(progress: earned)),
      );

      expect(find.textContaining('12 רשומות · 4 שנים'), findsOneWidget);
      expect(find.textContaining('אין הגבלה'), findsOneWidget);
    });

    testWidgets('and says so on the garage list too, in one line',
        (tester) async {
      await tester.pumpWidget(host(const DocumentedProgressMeter(
        progress: DocumentedProgress(records: 12, months: 48),
        compact: true,
      )));

      expect(find.textContaining('תיק מתועד · 12 רשומות · 4 שנים'),
          findsOneWidget);
    });

    testWidgets('an empty garage still gets the invitation, not a zero meter',
        (tester) async {
      await tester.pumpWidget(host(const DocumentedProgressMeter(
        progress: DocumentedProgress(records: 0, months: 0),
      )));

      expect(find.byType(Text), findsNothing);
    });
  });

  testWidgets('under way, the threshold is named as a minimum', (tester) async {
    // Same two numbers as before; what changed is that the sentence no longer
    // reads as the end of the job.
    await tester.pumpWidget(host(const DocumentedProgressMeter(
      progress: DocumentedProgress(records: 1, months: 2),
    )));

    expect(find.textContaining('1 מתוך 3 רשומות'), findsOneWidget);
    expect(find.textContaining('המינימום לתג'), findsOneWidget);
  });

  test('the call sites stopped deciding for the widget', () {
    // Both screens used to hide the meter once the badge was earned, which is
    // exactly the case this change exists to show.
    for (final path in [
      'lib/presentation/screens/buyer/garage_screen.dart',
      'lib/presentation/screens/buyer/vehicle_detail_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      final at = src.indexOf('DocumentedProgressMeter');
      final before = src.substring(at - 400, at);
      expect(before.contains('!vehicle.hasDocumentedHistory'), isFalse,
          reason: path);
    }
  });
}
