#!/usr/bin/env bash
# Checks every outbound link the landing page makes, against the live site.
#
# Written after the landing page's main download button spent a day returning
# 404: release v0.6 shipped its APK as `app-release.apk`, the button still
# pointed at `app-arm64-v8a-release.apk` from v0.5, and nothing anywhere
# noticed. A deploy that verifies its own bundle by md5 and never opens its own
# front door is checking the wrong thing.
#
#   bash tool/check_links.sh
set -uo pipefail

SITE="https://bonnetcheck.web.app"
fail=0

check() {
  local url="$1" what="$2"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 30 "$url")
  if [ "$code" = "200" ]; then
    printf '  ok   %-3s  %s\n' "$code" "$what"
  else
    printf '  FAIL %-3s  %s\n    %s\n' "$code" "$what" "$url"
    fail=1
  fi
}

echo "==> Landing page"
check "$SITE/" "the landing page itself"
check "$SITE/app/" "the app"
check "$SITE/robots.txt" "robots.txt"
check "$SITE/sitemap.xml" "sitemap.xml"

echo
echo "==> Every href the landing page points outward at"
# Pull the real hrefs out of the deployed HTML rather than the local file, so
# this checks what visitors actually get.
curl -s "$SITE/" \
  | grep -oE 'href="(https?://[^"]+|/[^"#][^"]*)"' \
  | sed -E 's/^href="//; s/"$//' \
  | sort -u \
  | while read -r href; do
      case "$href" in
        /*) check "$SITE$href" "$href" ;;
        *)  check "$href" "$href" ;;
      esac
    done

echo
echo "==> The APK a visitor actually downloads"
# The button links straight at the asset now, not at the releases page, so a
# release published without this exact filename breaks the download for
# everyone while the releases page keeps returning 200. That is the failure
# this script was written for, and checking the page instead of the file would
# have missed it.
check "https://github.com/david6212/autoproof2/releases/latest/download/app-arm64-v8a-release.apk" "the APK itself"

echo
if [ "$fail" = "0" ]; then
  echo "All links resolve."
else
  echo "Some links are broken — see FAIL above."
fi
exit $fail
