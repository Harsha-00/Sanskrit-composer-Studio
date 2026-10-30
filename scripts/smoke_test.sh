#!/bin/sh
# Checks a running Studio: ./scripts/smoke_test.sh http://localhost:4567
# Exits non-zero if any endpoint fails or returns no results.
BASE="${1:-http://localhost:4567}"
fail=0

check() { # name, path, text that must appear in the response
  body=$(curl -fsS -m 20 "$BASE$2") || { echo "FAIL $1 (request failed)"; fail=1; return; }
  case "$body" in
    *"$3"*) echo "ok   $1" ;;
    *) echo "FAIL $1 (missing: $3)"; fail=1 ;;
  esac
}

check "page"            "/"                                        "Credits &amp; Thanks"
check "config"          "/api/config"                              "https://ashtadhyayi.com"
check "stats"           "/api/stats"                               '"dict_entries":757713'
check "dictionary"      "/api/dictionary/search?q=dharma"          "धर्म"
check "sutra"           "/api/sutra/detail?code=1.1.1"             "वृद्धिरादैच्"
check "dhatu search"    "/api/dhatu/search?q=bhU"                  "भू"
check "shabda search"   "/api/shabda/search?q=rAma"                "राम"
check "sandhi"          "/api/tools/sandhi?mode=join&pada1=deva&pada2=Alaya" "देवालय"

for gone in /andhrabharati/inc/abtnsV2gMin.js /api/compositions /api/bookmarks; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "$BASE$gone")
  if [ "$code" = 404 ]; then echo "ok   $gone is not served"; else echo "FAIL $gone returned $code"; fail=1; fi
done

exit $fail
