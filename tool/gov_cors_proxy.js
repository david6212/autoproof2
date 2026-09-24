/**
 * Cloudflare Worker — a CORS shim in front of data.gov.il.
 *
 * DEPLOYED AND SERVING PRODUCTION TRAFFIC since 19/08/2026, on David's
 * Cloudflare account; the URL lives in `ApiConstants.govProxyHost`. This
 * header said "NOT DEPLOYED" for three days after it went live, which is
 * exactly the kind of comment that gets believed.
 *
 * Written on 18/08/2026, when data.gov.il stopped sending
 * `Access-Control-Allow-Origin` on its datastore_search responses. Verified
 * that day: the API still answers 200 to a server, and the browser at
 * bonnetcheck.web.app is blocked outright — "No 'Access-Control-Allow-Origin'
 * header is present". Nothing in the Flutter code can work around that; the
 * browser enforces it from the server's headers.
 *
 * The Android build is unaffected — CORS is a browser rule — so this exists
 * only to keep the web app's government data alive.
 *
 * Deploy (David's account; free tier covers 100k requests/day):
 *   1. Cloudflare dashboard → Workers & Pages → Create → paste this file.
 *   2. Note the workers.dev URL, or bind a route on bonnetcheck.com.
 *   3. Put the workers.dev origin in `ApiConstants.govProxyHost` and redeploy
 *      the web build. Web only — the phone keeps calling the registry direct.
 *
 * Deliberately narrow. It forwards nothing but datastore_search GETs to one
 * host, and reflects only our own origins back — an open relay on a
 * government dataset is somebody else's bandwidth bill and our name on it.
 */

const UPSTREAM = 'https://data.gov.il';
const ALLOWED_PATHS = ['/api/3/action/datastore_search'];
const ALLOWED_ORIGINS = [
  'https://bonnetcheck.web.app',
  'https://autoproof-8d827.web.app',
  'https://otov.web.app',
  'https://bonnetcheck.com',
  'https://www.bonnetcheck.com',
];

// `flutter run -d chrome` picks a fresh random port every launch, so the dev
// origin cannot be listed. Loopback only, any port: a page served from the
// developer's own machine is not somebody else's site borrowing the proxy.
const DEV_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/;

function allowed(origin) {
  return ALLOWED_ORIGINS.includes(origin) || DEV_ORIGIN.test(origin);
}

// What the app sends from a phone, where there is no Origin header to check.
//
// Not a secret, and not pretending to be one — a value shipped in a build is
// public the moment somebody unzips it. It is a name on the request, and that
// is enough for the thing it has to do: a Worker that answers anything is a
// proxy operated for third parties, which Cloudflare's terms prohibit
// (§2.2.1(j)), and one that answers only requests claiming to be this app is a
// CORS shim for this app. The difference is not how hard it is to forge; it is
// what the service is.
const CLIENT_HEADER = 'X-BonnetCheck-Client';

/// The largest `limit` the app itself asks for: the fuel-station list.
const MAX_LIMIT = 2000;

function corsHeaders(origin) {
  const headers = {
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Max-Age': '86400',
    // Without this a cache could hand one origin's allow-header to another,
    // which reads as a random CORS failure that no amount of redeploying fixes.
    Vary: 'Origin',
  };
  if (allowed(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
  }
  return headers;
}

export default {
  async fetch(request) {
    const origin = request.headers.get('Origin') ?? '';
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 });
    }
    if (!ALLOWED_PATHS.includes(url.pathname)) {
      return new Response('Not found', { status: 404 });
    }
    // Refuse before spending an upstream request. An unlisted origin gets no
    // allow-header anyway, so answering it would only burn the free tier.
    //
    // Two ways to be recognised, because the two clients are not alike:
    //
    // - **A browser** sends an Origin, and it has to be on the list.
    // - **A phone** sends none. Dart's HTTP client is not subject to CORS and
    //   there is no Origin to inspect, so the app names itself in a header
    //   instead. This route matters: the phone calls data.gov.il directly and
    //   only falls back here when that fails, so refusing an Origin-less
    //   request would quietly delete the fallback rather than tighten it.
    //
    // Anything that is neither — a bare curl, the URL pasted into a tab — is
    // refused now. It used to be allowed on the grounds that whatever can omit
    // a header can forge one, which is true and beside the point: the question
    // Cloudflare's terms ask is whether we run a proxy for other people, and
    // with that door open we did.
    const named = request.headers.get(CLIENT_HEADER) !== null;
    if (origin ? !allowed(origin) : !named) {
      return new Response('Forbidden', { status: 403 });
    }

    // A relay is also a volume problem: one unbounded `limit` pulls half a
    // megabyte per request through a free account. 2000 is the largest the app
    // itself asks for (the fuel-station list) — capping lower would break that
    // screen on the web, which is the whole reason this Worker exists.
    const limit = Number(url.searchParams.get('limit'));
    if (Number.isFinite(limit) && limit > MAX_LIMIT) {
      return new Response('Bad Request', { status: 400 });
    }

    const upstream = new URL(UPSTREAM + url.pathname + url.search);
    const res = await fetch(upstream, {
      headers: { Accept: 'application/json' },
      // The datasets change daily at most, so a shared cache both speeds the
      // app up and keeps us well clear of whatever rate limit is in play.
      cf: { cacheTtl: 600, cacheEverything: true },
    });

    const body = await res.text();
    return new Response(body, {
      status: res.status,
      headers: {
        ...corsHeaders(origin),
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'public, max-age=300',
      },
    });
  },
};
