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
        plate: '46592550',
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
      final masked = PlateFormatter.masked('46592550');
      expect(masked, '46-592-550'.replaceAll(RegExp(r'\d'), '*'));
      expect(RegExp(r'\d').hasMatch(masked), isFalse);
    });

    test('works for the seven-digit grouping too', () {
      expect(PlateFormatter.masked('4659255'), '***-**-**');
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

    testWidgets('shows it to the one reader who owns the car', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GovDataCard(data: car(), showPlate: true),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('46-592-550'), findsOneWidget);
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
}
