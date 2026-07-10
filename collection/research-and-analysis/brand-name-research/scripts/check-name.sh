#!/usr/bin/env bash
# Passive availability screen for a single brand-name candidate.
# NO registrar search boxes, NO GoDaddy/Namecheap APIs — those can trigger domain
# front-running. Only DNS, whois, and public read-only APIs (which do not "claim" anything).
#
# Usage: check-name.sh <name> [--tlds com,io,dev,ai] [--gplay]
#   <name>   candidate (letters/numbers/hyphen). Domain checks strip spaces.
# Output: one block per name; ends with a VERDICT line: PASS or FAIL(reasons).
#
# Exit code: 0 always (verdict is in the text, so batch callers can keep going).
set -uo pipefail

NAME="${1:?Usage: check-name.sh <name> [--tlds com,io,dev,ai]}"; shift || true
TLDS="com,io,dev,ai,app,co"
while [ $# -gt 0 ]; do
  case "$1" in
    --tlds) TLDS="$2"; shift ;;
  esac
  shift || true
done

# slug for domains/handles: lowercase, strip non-alnum (keep hyphen)
SLUG="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+//g')"
REASONS=()

echo "=== $NAME  (slug: $SLUG) ==="

# --- Domains -----------------------------------------------------------------
COM_TAKEN=0
ANY_DOMAIN_FREE=0
IFS=',' read -ra TLD_ARR <<< "$TLDS"
for tld in "${TLD_ARR[@]}"; do
  domain="$SLUG.$tld"
  ns="$(dig +short "$domain" NS 2>/dev/null)"
  a="$(dig +short "$domain" A 2>/dev/null)"
  if [ -z "$ns" ] && [ -z "$a" ]; then
    # No DNS — probe whois to confirm truly unregistered
    w="$(whois "$domain" 2>/dev/null)"
    if echo "$w" | grep -qiE 'no match|not found|no data found|no entries found|status: *free|domain not found|available'; then
      echo "  domain $domain        : AVAILABLE"
      ANY_DOMAIN_FREE=1
    else
      echo "  domain $domain        : registered (no DNS, but whois has a record)"
      [ "$tld" = "com" ] && COM_TAKEN=1
    fi
  else
    echo "  domain $domain        : TAKEN (has DNS)"
    [ "$tld" = "com" ] && COM_TAKEN=1
  fi
done
[ "$ANY_DOMAIN_FREE" = "0" ] && REASONS+=("no requested TLD available")

# --- Apple App Store (the classic trap) --------------------------------------
APP_HITS="$(curl -s "https://itunes.apple.com/search?term=$(printf '%s' "$SLUG" | sed 's/ /+/g')&entity=software&limit=5" \
  | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except: print('?'); sys.exit()
n=d.get('resultCount',0)
hits=[r['trackName'] for r in d.get('results',[]) if r.get('trackName','').lower().replace(' ','').startswith('$SLUG'.replace('-',''))]
print(str(len(hits))+'|'+'; '.join(hits[:3]))
" 2>/dev/null)"
APP_N="${APP_HITS%%|*}"; APP_LIST="${APP_HITS#*|}"
if [ "${APP_N:-0}" != "0" ] && [ -n "${APP_N:-}" ] && [ "$APP_N" != "?" ]; then
  echo "  apple app store         : MATCH ($APP_LIST)"
  REASONS+=("exists on App Store: $APP_LIST")
else
  echo "  apple app store         : clear"
fi

# --- GitHub org/user ---------------------------------------------------------
gh_code="$(curl -s -o /dev/null -w '%{http_code}' "https://github.com/$SLUG")"
if [ "$gh_code" = "200" ]; then
  echo "  github.com/$SLUG        : TAKEN"
else
  echo "  github.com/$SLUG        : free"
fi

# --- npm + PyPI (only matters for dev tools / libraries) ---------------------
npm_code="$(curl -s -o /dev/null -w '%{http_code}' "https://registry.npmjs.org/$SLUG")"
pypi_code="$(curl -s -o /dev/null -w '%{http_code}' "https://pypi.org/pypi/$SLUG/json")"
echo "  npm package             : $([ "$npm_code" = "200" ] && echo TAKEN || echo free)"
echo "  pypi package            : $([ "$pypi_code" = "200" ] && echo TAKEN || echo free)"

# --- Verdict -----------------------------------------------------------------
# FAIL if it's already an app, or no desired domain is available.
if [ "${#REASONS[@]}" -eq 0 ]; then
  echo "  VERDICT: PASS"
else
  echo "  VERDICT: FAIL — ${REASONS[*]}"
fi
echo ""
