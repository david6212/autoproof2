import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// data.gov.il — Israeli Ministry of Transport public vehicle registry.
class ApiConstants {
  ApiConstants._();

  /// The registry's own host. Every platform but the browser talks to it.
  static const govDirectHost = 'https://data.gov.il';

  /// Our CORS shim, or empty while none is deployed.
  ///
  /// On 18/08/2026 data.gov.il stopped sending `Access-Control-Allow-Origin`,
  /// which means a browser refuses the response before the app can read it —
  /// every government fact on bonnetcheck.web.app went blank in one day.
  /// Nothing in Dart can work around that: the browser enforces it from the
  /// server's headers, and the server is not ours.
  ///
  /// Deployed 19/08/2026 from `tool/gov_cors_proxy.js`, on David's Cloudflare
  /// account. Origin only, no path — [_govPath] is appended.
  ///
  /// The URL is public by necessity: it ships inside the web bundle, because
  /// the browser is what calls it. What keeps it ours is the Worker's origin
  /// allowlist plus a path allowlist of exactly one endpoint.
  static const govProxyHost =
      'https://sweet-breeze-97b0.davidmalede.workers.dev';

  static const _govPath = '/api/3/action/datastore_search';

  /// Where the app actually sends a registry query.
  ///
  /// The proxy is used **only** on the web, and only once it exists. Two
  /// reasons to keep the phone on the direct route: CORS is a browser rule, so
  /// the APK never needed the shim; and routing the phone through it too would
  /// hand a Worker outage the power to take down the one build that is
  /// currently working, while doubling the traffic on a free tier.
  ///
  /// While [govProxyHost] is empty the web build calls the registry directly
  /// and fails in the open — the honest state, and better than a placeholder
  /// URL whose 404s would look like the registry answering.
  static String get govApiBase =>
      endpointFor(isWeb: kIsWeb, proxyHost: govProxyHost);

  /// [govApiBase]'s rule, with its two inputs made arguments so a test can ask
  /// about a platform it is not running on.
  @visibleForTesting
  static String endpointFor({required bool isWeb, required String proxyHost}) =>
      (isWeb && proxyHost.isNotEmpty)
          ? '$proxyHost$_govPath'
          : '$govDirectHost$_govPath';

  static const vehicleResourceId = '053cea08-09bc-40ec-8f7a-156f0677aff3';

  // Additional Ministry of Transport datasets.
  static const vehicleHistoryResourceId =
      '56063a99-8a3e-4ff4-912e-5966c0279bad'; // km at last test, structural change
  static const openRecallResourceId =
      '36bf1404-0be4-49d2-82dc-2f1ead4a8b93'; // open (unperformed) recalls
  static const offRoadResourceId =
      '851ecab1-0622-4dbe-a6c7-f950cf82abf9'; // off-road / final cancellation
  static const disabilityTagResourceId =
      'c8b9f9c8-4612-4068-934f-d4acd2e3c06e'; // disability parking tag

  // Vehicle MODELS ("תוצרים ודגמים של כלי רכב WLTP"). The per-vehicle registry
  // carries no engine capacity, seat count, drivetrain or body type — those
  // live here, per model. Join on tozeret_cd + degem_cd + shnat_yitzur.
  static const modelSpecResourceId = '142afde2-6228-49f9-8a29-9b6c3a0cbe40';

  // Licensed garages & inspection institutes ("מוסכים ומכוני רישוי").
  static const garagesResourceId = 'bb68386a-a331-4bbc-b668-bba2766d517d';

  /// Public fuel stations, Ministry of Energy — 1,255 records, and unusually
  /// for a gov dataset they already carry WGS84 coordinates, so nothing has to
  /// be geocoded. Fields: מס_מינהל_הדלק · חברה · שם_תחנה · כתובת ·
  /// רשות_מקומית · X · Y (Israeli grid) · "נ.צ. אורך"/"נ.צ. רוחב" (lon/lat).
  static const fuelStationsResourceId =
      '5537a0ef-3eeb-449c-90c8-51e27564f0cb';

  /// Maximum petroleum prices **at the refinery gate**, Ministry of Energy,
  /// one national figure per product per month.
  ///
  /// This is NOT a pump price and must never be shown as one — it is the
  /// wholesale price before excise and VAT, roughly half of what a driver
  /// pays. There is no per-station price dataset in Israel at all; diesel is
  /// not price-controlled, so nobody publishes it. Fields: תאריך · מוצר ·
  /// יחידת מידה · מחיר (₪ per kilolitre).
  static const refineryPricesResourceId =
      'aaa40832-ac82-4c86-bac6-0d05c83f576f';

  /// The product row used as the diesel reference.
  static const dieselProduct = 'סולר לתחבורה במכלית';

  // The `miktzoa` (specialty) value marking a pre-purchase/sale inspection
  // center — exactly the "בדיקת רכב לפני קנייה" a buyer needs (~134 nationwide).
  static const inspectionMiktzoa = 'בדיקות-רכב )קניה ומכירה)';

  // Usage:
  // GET https://data.gov.il/api/3/action/datastore_search
  //   ?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3
  //   &q=1234567          ← plate number WITHOUT dashes
  //   &limit=1
}
