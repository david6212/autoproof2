import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/repositories/operator_inbox_repository.dart';

/// SEC-23: one open report per person per subject.
///
/// The rules accept a report only under the id `subject__reporter`, rebuilt
/// from the report's own fields (test/rules/inbox_fuel_escort.mjs). This pins
/// the client half: the id it builds, and that all three writers build it.
void main() {
  test('the id is the subject, then the reporter', () {
    expect(reportId(['car1', 'note1'], 'uidA'), 'car1__note1__uidA');
    expect(reportId(['listing_report', 'car1'], 'uidA'),
        'listing_report__car1__uidA');
  });

  test('it splits into exactly three parts, as the rule demands', () {
    // `isOwnReportId` in the rules: split('__').size() == 3.
    for (final id in [
      reportId(['car1', 'note1'], 'uidA'),
      reportId(['place1', 'uidB'], 'uidA'),
      reportId(['plate_history', 'car1'], 'uidA'),
    ]) {
      expect(id.split('__'), hasLength(3), reason: id);
      expect(id.split('__').last, 'uidA');
    }
  });

  test('no inbox writer uses an auto-id any more', () {
    final car = File('lib/data/repositories/car_repository.dart')
        .readAsStringSync();
    final place = File('lib/data/repositories/place_repository.dart')
        .readAsStringSync();
    expect(car, isNot(contains("collection('note_reports').add(")));
    expect(car, isNot(contains("collection('data_corrections').add(")));
    expect(car, contains("collection('note_reports').doc(reportId("));
    expect(car, contains('.doc(reportId([kind, carId], reporterUid))'));
    expect(place, contains('.doc(reportId([placeId, reviewUid], reporterUid))'));
  });

  test('a waiting report is not filed twice', () {
    final inbox = File('lib/data/repositories/operator_inbox_repository.dart')
        .readAsStringSync();
    expect(inbox, contains(
        "if (existing != null && existing['handledAt'] == null) return false;"));
  });

  test('the person is told when theirs is already waiting', () {
    for (final f in [
      'lib/presentation/widgets/car_notes_section.dart',
      'lib/presentation/widgets/plate_history_card.dart',
      'lib/presentation/widgets/report_listing_sheet.dart',
    ]) {
      expect(File(f).readAsStringSync(), matches(RegExp('כבר .*ממתינ|כבר .*ממתין')),
          reason: f);
    }
  });
}
