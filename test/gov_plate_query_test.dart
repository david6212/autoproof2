import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/data/sources/remote/gov_api_service.dart';

/// How a plate is asked for.
///
/// Pinned because the app spent an unknown number of days telling people the
/// registry had never heard of their car. `q=<plate>` — free text — stopped
/// matching plate numbers on data.gov.il, and nothing in the app could tell
/// the difference between "no such vehicle" and "this query no longer works":
/// both arrive as zero records.
///
/// A test cannot stop the ministry changing its search engine again. What it
/// can do is state which column each dataset is filtered on, so the next
/// person who sees "המספר לא נמצא" for a car they are looking at has one
/// place that says what the app actually asked.
void main() {
  const plate = '6984370';

  test('a plate is asked for by exact column, not by free text', () {
    final filter = GovApiService.plateFilter(
      GovApiService.plateFieldDefault,
      plate,
    );
    expect(jsonDecode(filter!), {'mispar_rechev': 6984370});
  });

  test('the column is numeric, so the plate is sent as a number', () {
    // A string would filter a numeric column to nothing at all — the same
    // silent zero-record answer this whole fix is about.
    expect(
      GovApiService.plateFilter(GovApiService.plateFieldDefault, plate),
      '{"mispar_rechev":6984370}',
      reason: 'quoted, it would read as text and match a numeric column never',
    );
  });

  test("recalls and disability tags spell the column differently", () {
    // Not a typo to be tidied. These are the ministry's own column names, and
    // the one with a space in it is real.
    expect(GovApiService.plateFieldRecalls, 'MISPAR_RECHEV');
    expect(GovApiService.plateFieldDisability, 'MISPAR RECHEV');
    expect(
      jsonDecode(GovApiService.plateFilter(
          GovApiService.plateFieldDisability, plate)!),
      {'MISPAR RECHEV': 6984370},
    );
  });

  test('junk in gets no query at all, rather than a query for nothing', () {
    expect(GovApiService.plateFilter(GovApiService.plateFieldDefault, ''),
        isNull);
    expect(GovApiService.plateFilter(GovApiService.plateFieldDefault, 'abc'),
        isNull);
  });
}
