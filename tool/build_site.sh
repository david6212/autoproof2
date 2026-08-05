#!/usr/bin/env bash
# Builds everything Firebase Hosting serves, into build/hosting:
#
#   /            the static landing page (landing/)
#   /app/        the Flutter app
#
# Firebase serves one directory per site, so the two have to be assembled
# rather than pointed at separately. Run this instead of `flutter build web`
# before deploying:
#
#   bash tool/build_site.sh && firebase deploy --only hosting --project autoproof-8d827
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build/hosting

echo "==> Building the app with base href /app/"
# The base href has to match where it is served from, or every asset request
# resolves against / and 404s.
#
# MSYS_NO_PATHCONV stops Git Bash "helpfully" rewriting the leading slash into
# a Windows path — without it Flutter receives C:/Program Files/Git/app/.
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /app/

echo "==> Assembling $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"

cp -r landing/. "$OUT"/
mkdir -p "$OUT/app"
cp -r build/web/. "$OUT/app"/

# The landing page borrows the app's icons; keep the copy honest.
test -f "$OUT/app/favicon.png" || echo "    note: app/favicon.png missing"

echo
echo "==> Done"
echo "    landing : $(du -sh "$OUT" --exclude=app 2>/dev/null | cut -f1) in $OUT"
echo "    app     : $OUT/app"
echo
echo "    Deploy:  firebase deploy --only hosting --project autoproof-8d827"
