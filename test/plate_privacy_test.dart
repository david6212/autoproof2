import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/app/theme.dart';
import 'package:bonnetcheck/core/utils/plate_formatter.dart';
import 'package:bonnetcheck/data/models/gov_data_model.dart';
import 'package:bonnetcheck/presentation/widgets/gov_data_card_widget.dart';

/// A listing must not tell a stranger the plate.
///
/// Sellers tape over the number before photographing a car; printing it under
/// the photo overrules them. What the app is selling is the registry record,
/// and the record does not need the number attached to be worth reading.
///
/// The scans below are over the source rather than over one screen, because
/// every leak found so far was somewhere nobody thought of as "showing the
/// plate": a route parameter, and a search haystack.
void main() {
  GovData car() => GovData(
        plate: '11111111',
        make: 'מאזדה',
        commercialName: 'CX-5',
        model: 'CX-5',
        year: 2017,
        color: 'אפור',
        fuelType: 'בנזין',
        ownershipType: 'פרטי',
        trim: '',
        lastTestDate: DateTime(2026, 7, 21),
        licenseExpiry: DateTime(2027, 7, 19),
        safetyRating: '',
        chassis: '',
      );

  group('the masked form', () {
    test('keeps the shape of a plate and none of its digits', () {
      final masked = PlateFormatter.masked('11111111');
      expect(masked, '46-592-550'.replaceAll(RegExp(r'\d'), '*'));
      expect(RegExp(r'\d').hasMatch(masked), isFalse);
    });

    test('works for the seven-digit grouping too', () {
      expect(PlateFormatter.masked('9999999'), '***-**-**');
    });

    test('an empty plate produces nothing rather than a row of stars', () {
      expect(PlateFormatter.masked(''), '');
    });
  });

  group('the official record card', () {
    testWidgets('hides the plate unless told otherwise', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: GovDataCard(data: car()))),
      ));
      await tester.pump();

      expect(find.text('46-592-550'), findsNothing);
      expect(find.text('**-***-***'), findsOneWidget);
    });

    testWidgets('has no way to print the digits at all', (tester) async {
      // The card used to take a `showPlate` flag. It is gone: one widget
      // decides how a plate is drawn, and the owner's reveal is a deliberate
      // tap on the screen above rather than a boolean threaded through a
      // card that four screens could pass wrongly.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(child: GovDataCard(data: car())),
        ),
      ));
      await tester.pump();

      expect(find.text('46-592-550'), findsNothing);
    });
  });

  group('the two leaks that were not on screen at all', () {
    test('no navigation puts a plate in the path', () {
      // It was `/car/$plate/history`, which showed the number in the address
      // bar on the web and travelled inside any link the buyer then shared.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (RegExp(r"""(push|go|pushReplacement)\(\s*'/[^']*\$plate""")
              .hasMatch(line)) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'route by the listing id; the plate is not a public name');
    });

    test('no public search matches on the plate', () {
      // Leaving the plate in the haystack would have made the masking
      // cosmetic: type a number, and the single listing it belongs to falls
      // out of a search anyone can run.
      final offenders = <String>[];
      for (final path in [
        'lib/presentation/providers/cars_provider.dart',
        'lib/presentation/widgets/search_filter_sheet.dart',
      ]) {
        final lines = File(path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(r'${c.plate}')) {
            offenders.add('$path:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('one widget draws every plate', () {
    test('nothing else is allowed to print the digits', () {
      // `PlateFormatter.withDashes` is the unmasked form. Two screens had
      // each grown a private copy of it, and the copies disagreed about how a
      // seven-digit plate is grouped — which is what happens to a rule that
      // lives in more than one place.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final name = entity.uri.pathSegments.last;
        if (name == 'plate_text.dart' || name == 'plate_formatter.dart') {
          continue;
        }
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('PlateFormatter.withDashes(')) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'draw plates with PlateText');
    });

    test('no screen drops a raw plate into a line of text', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('Text(') && RegExp(r'\$\{?\w+\.plate').hasMatch(line)) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });

  test('no screen offers a search by plate', () {
    // The haystack lost the plate; a placeholder still advertising it would
    // be the app breaking a promise on the reader's first attempt.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('hintText') &&
            (lines[i].contains('מספר רכב') ||
                lines[i].contains('מספר רישוי') &&
                    lines[i].contains('חיפוש'))) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no real plate is hard-coded anywhere in the project', () {
    // The four demo listings once sat on four real, registered private
    // vehicles — an invented advertisement attached to somebody's actual car.
    // The live data was replaced with synthetic plates; this stops the
    // numbers creeping back in through a fixture or a seed script, which is
    // exactly how they would.
    const real = ['4659255', '3780034', '20837803', '67688002', '46592550'];
    final offenders = <String>[];
    for (final dir in const ['lib', 'test', 'tool', 'landing']) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final entity in d.listSync(recursive: true)) {
        if (entity is! File) continue;
        // Binary files are skipped rather than decoded — a font or a
        // screenshot cannot contain a plate as text, and reading one as UTF-8
        // throws.
        const binary = ['.png', '.jpg', '.jpeg', '.woff2', '.ttf', '.otf',
            '.ico', '.webp', '.jks', '.keystore'];
        if (binary.any(entity.path.endsWith)) continue;
        final text = entity.readAsStringSync();
        for (final plate in real) {
          // Two files name them on purpose: this one, which has to hold the
          // list to search for, and the seed script, whose comment explains
          // why the number must never be used again.
          const namesThemDeliberately = [
            'plate_privacy_test.dart',
            'seed_demo_passport.py',
          ];
          if (text.contains(plate) &&
              !namesThemDeliberately.any(entity.path.endsWith)) {
            offenders.add('${entity.path} → $plate');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('the VIN is masked too', (tester) async {
    // A VIN is a stronger and more permanent identifier than a plate — and
    // the key input to plate cloning. Masking the plate while printing the
    // chassis number underneath it protects nobody.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: GovDataCard(
            data: car().withExtras(
              history: const {'misgeret': 'JMZKF6W7A00123456'},
              recalls: const [],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('JMZKF6W7'), findsNothing);
  });
}
