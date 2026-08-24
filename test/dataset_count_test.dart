import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/api_constants.dart';

/// The number the app says out loud has to be the number it queries.
///
/// A compliance audit found the landing page claiming five Ministry of
/// Transport datasets per car while the code queried a different set — and
/// nothing tied the sentence to the code, so neither side knew. The count is
/// not a detail here: "five government datasets" is the product's whole pitch,
/// and a pitch that is off by one is a claim nobody checked.
void main() {
  test('five datasets per vehicle, and no duplicates', () {
    expect(ApiConstants.perVehicleDatasets.length, 5);
    expect(ApiConstants.perVehicleDatasets.toSet().length, 5,
        reason: 'the same resource id listed twice would inflate the count');
  });

  test('the copy quotes the same number', () {
    final count = ApiConstants.perVehicleDatasets.length;
    const hebrew = {
      4: 'ארבעה',
      5: 'חמישה',
      6: 'שישה',
      7: 'שבעה',
    };

    final landing = File('landing/index.html').readAsStringSync();
    expect(landing, contains('${hebrew[count]} מאגרים'),
        reason: 'the landing page names a different number than the code uses');

    final journey =
        File('lib/presentation/widgets/buyer_journey_card.dart')
            .readAsStringSync();
    expect(journey, contains('$count מאגרי משרד התחבורה'));
  });

  test('the garages directory is not counted as a fact about a car', () {
    expect(
      ApiConstants.perVehicleDatasets.contains(ApiConstants.garagesResourceId),
      isFalse,
    );
  });
}
