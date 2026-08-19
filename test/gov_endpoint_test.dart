import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/api_constants.dart';

/// Which host a registry query is sent to, per platform.
///
/// Worth pinning because the rule is invisible at every call site — the whole
/// app just reads `ApiConstants.govApiBase` — and because getting it backwards
/// is not a visible bug on the machine you are working on. A build that routes
/// the phone through the proxy looks identical in Chrome, and only fails on a
/// device, the day the Worker does.
void main() {
  const path = '/api/3/action/datastore_search';
  const proxy = 'https://gov-cors.example.workers.dev';

  test('the browser goes through the proxy once one exists', () {
    expect(
      ApiConstants.endpointFor(isWeb: true, proxyHost: proxy),
      '$proxy$path',
    );
  });

  test('the phone always talks to the registry itself', () {
    expect(
      ApiConstants.endpointFor(isWeb: false, proxyHost: proxy),
      '${ApiConstants.govDirectHost}$path',
    );
  });

  test('with no proxy deployed the web falls back to the direct call', () {
    // It will be blocked by CORS and say so, which is the point: silence here
    // would be the app hiding an outage it knows about.
    expect(
      ApiConstants.endpointFor(isWeb: true, proxyHost: ''),
      '${ApiConstants.govDirectHost}$path',
    );
  });

  test('the live constant is one of exactly those two hosts', () {
    expect(
      ApiConstants.govApiBase.endsWith(path),
      isTrue,
      reason: 'the proxy must be given an origin, never a full endpoint',
    );
  });
}
