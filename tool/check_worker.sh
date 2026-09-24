#!/usr/bin/env bash
# Is the deployed Cloudflare Worker the one in this repo?
#
# The Worker exists so the web app can read data.gov.il, which blocks browser
# requests. It must NOT relay for anybody else: Cloudflare's terms forbid
# running a proxy for third parties, and the bill lands on a personal account.
#
# The gate: an allow-listed Origin (a browser) OR the client header (the phone,
# which sends no Origin at all and would lose its fallback if we demanded one).
#
# Run it after deploying the Worker, and before any release.
#
#   bash tool/check_worker.sh
#
set -u

WORKER="${WORKER_URL:-https://sweet-breeze-97b0.davidmalede.workers.dev}"
PATH_Q="/api/3/action/datastore_search?resource_id=053cea08-09bc-40ec-8f7a-156f0677aff3&limit=1"
FUEL="5537a0ef-3eeb-449c-90c8-51e27564f0cb"

fail=0

check() {
  local want="$1" label="$2"; shift 2
  local got
  got=$(curl -s -o /dev/null -w '%{http_code}' "$@")
  if [ "$got" = "$want" ]; then
    printf '  ok    %-42s %s\n' "$label" "$got"
  else
    printf '  FAIL  %-42s got %s, expected %s\n' "$label" "$got" "$want"
    fail=1
  fi
}

echo "worker: $WORKER"

# A stranger with the URL — the shape that made it an open relay.
check 403 "bare request, no Origin, no client header" "$WORKER$PATH_Q"

# The phone: no Origin, names itself.
check 200 "phone (X-BonnetCheck-Client)" -H 'X-BonnetCheck-Client: app' "$WORKER$PATH_Q"

# A browser on somebody else's site.
check 403 "foreign Origin" -H 'Origin: https://evil.example' "$WORKER$PATH_Q"

# Our own web app.
check 200 "our Origin" -H 'Origin: https://bonnetcheck.web.app' "$WORKER$PATH_Q"

# Volume: the app's own largest request must pass, anything larger must not.
check 200 "limit=2000 (the fuel list the app asks for)" \
  -H 'X-BonnetCheck-Client: app' \
  "$WORKER/api/3/action/datastore_search?resource_id=$FUEL&limit=2000"
check 400 "limit=99999 (a relay pulling volume)" \
  -H 'X-BonnetCheck-Client: app' \
  "$WORKER/api/3/action/datastore_search?resource_id=$FUEL&limit=99999"

if [ "$fail" = 0 ]; then
  echo "all checks passed"
else
  echo
  echo "The deployed Worker does not match tool/gov_cors_proxy.js."
  echo "Cloudflare dashboard > Workers & Pages > sweet-breeze-97b0 > Edit code,"
  echo "paste tool/gov_cors_proxy.js, Deploy, then run this again."
fi
exit "$fail"
