import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bonnetcheck/core/constants/api_constants.dart';
import 'package:bonnetcheck/data/sources/remote/gov_api_service.dart';

/// A screen is allowed to fail. It is not allowed to spin forever.
///
/// Reported from a real phone on 26/08: the fuel screen never left its loading
/// state — no error, no message, no end. The same dataset came back in half a
/// second from a browser and from `dart:io` on a desktop, so nothing about the
/// data or the endpoint was wrong.
///
/// The gap was in what Dio's timeouts actually cover. `connectTimeout` is
/// measured from the TCP connect and does not include the DNS lookup before
/// it; `receiveTimeout` measures the gap between body chunks, so a request
/// that never produces a first chunk never trips it either. Between them sits
/// a state with no deadline at all, and a `FutureProvider` awaiting it stays
/// in `loading` for as long as the app is open.
class _HangingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _,
          Future<void>? __) =>
      // Never completes. Precisely the failure a stalled resolver produces.
      Completer<ResponseBody>().future;

  @override
  void close({bool force = false}) {}
}

/// Fails for one host and answers for the other, so the fallback can be
/// observed rather than assumed.
class _HostSplitAdapter implements HttpClientAdapter {
  _HostSplitAdapter({required this.failingHost});

  final String failingHost;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _,
      Future<void>? __) async {
    calls.add(options.uri.host);
    if (options.uri.host == failingHost) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulated: this network cannot reach that host',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'result': {
          'records': [
            {'שם_תחנה': 'תחנה', 'נ.צ. רוחב': '32.0', 'נ.צ. אורך': '34.8'},
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  test('a request that never answers ends as an error, not as a wait', () {
    final service = GovApiService(
      dio: _dio(_HangingAdapter()),
      // Production waits 20s; the behaviour under test is identical.
      deadline: const Duration(milliseconds: 50),
    );

    expect(
      service.fetchFuelStations(),
      throwsA(isA<GovApiException>()),
      reason: 'without a deadline this future never completes at all',
    );
  });

  test('the deadline covers every dataset, not just the fuel one', () {
    final service = GovApiService(
      dio: _dio(_HangingAdapter()),
      deadline: const Duration(milliseconds: 50),
    );

    // The plate lookup is the product's whole first promise. It hangs on the
    // same stall the fuel screen hit.
    expect(service.fetchRefineryPrices(), throwsA(isA<GovApiException>()));
    expect(service.fetchInspectionCenters(), throwsA(isA<GovApiException>()));
  });

  test('production ships the twenty-second deadline, not a test one', () {
    // The seam exists for the tests above; it must not become the default.
    expect(GovApiService.defaultDeadline, const Duration(seconds: 20));
    expect(GovApiService().requestDeadline, GovApiService.defaultDeadline);
  });

  group('falling back to the Worker', () {
    test('a phone that cannot reach the registry still gets its data',
        () async {
      final adapter = _HostSplitAdapter(failingHost: 'data.gov.il');
      final service = GovApiService(dio: _dio(adapter));

      final records = await service.fetchFuelStations();

      expect(records, hasLength(1));
      expect(adapter.calls.first, 'data.gov.il',
          reason: 'direct is still tried first \u2014 the fallback is a fallback');
      expect(adapter.calls.last, isNot('data.gov.il'),
          reason: 'and the second attempt goes somewhere else');
    });

    test('the same host is never tried twice', () async {
      // If the Worker is what failed, retrying the Worker only makes the
      // failure slower.
      final everything = _HostSplitAdapter(failingHost: 'data.gov.il');
      final service = GovApiService(dio: _dio(everything));
      await service.fetchFuelStations();

      expect(everything.calls.toSet(), hasLength(2),
          reason: 'two distinct hosts, one attempt each');
    });

    test('the fallback host is the deployed Worker', () {
      expect(ApiConstants.govApiFallback,
          startsWith(ApiConstants.govProxyHost));
      expect(ApiConstants.govApiFallback,
          endsWith('/api/3/action/datastore_search'));
    });
  });
}
