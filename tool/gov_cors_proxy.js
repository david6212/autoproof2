/**
 * Cloudflare Worker — a CORS shim in front of data.gov.il.
 *
 * NOT DEPLOYED. Written on 18/08/2026, when data.gov.il stopped sending
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
 *   3. Point `ApiConstants.baseUrl` at it and redeploy the web build.
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
  'http://localhost:8080', // flutter run -d chrome
];

function corsHeaders(origin) {
  const headers = {
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
  if (ALLOWED_ORIGINS.includes(origin)) {
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
