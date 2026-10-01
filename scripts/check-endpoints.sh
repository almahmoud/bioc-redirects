#!/usr/bin/env bash
# Check the live redirect endpoints against this repository.
# Usage: scripts/check-endpoints.sh   (CERT_DAYS sets the certificate warning window, default 21)
set -u

cd "$(dirname "$0")/.."

page_host=slack.bioconductor.org
page=sites/$page_host/public/index.html
cert_days=${CERT_DAYS:-21}

invite=$(sed -n 's/.*const redirectUrl = "\([^"]*\)".*/\1/p' "$page")
blog=$(sed -n 's/.*src="\([^"]*\)".*/\1/p' "$page")
if [ -z "$invite" ] || [ -z "$blog" ]; then
  echo "cannot read the invite or blog URL from $page" >&2
  exit 2
fi

# One "host target" pair per line.
redirects="
zulip.bioconductor.org $invite
chat.bioconductor.org $invite
"

failures=0
pass() { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }

# expect URL STATUS [LOCATION]
expect() {
  local want="$2${3:+ $3}" got
  got=$(curl -s -o /dev/null --max-time 15 -w '%{http_code} %{redirect_url}' "$1")
  got=${got% }
  if [ "$got" = "$want" ]; then
    pass "$1 -> $want"
  else
    fail "$1 -> got '$got', want '$want'"
  fi
}

certificate() {
  local pem
  pem=$(openssl s_client -connect "$1:443" -servername "$1" </dev/null 2>/dev/null | openssl x509 2>/dev/null)
  if [ -z "$pem" ]; then
    fail "$1 certificate: no answer"
  elif printf '%s\n' "$pem" | openssl x509 -noout -checkend $((cert_days * 86400)) >/dev/null; then
    pass "$1 certificate $(printf '%s\n' "$pem" | openssl x509 -noout -enddate)"
  else
    fail "$1 certificate expires within $cert_days days: $(printf '%s\n' "$pem" | openssl x509 -noout -enddate)"
  fi
}

expect "https://$page_host/" 200
if curl -s --max-time 15 "https://$page_host/" | cmp -s - "$page"; then
  pass "https://$page_host/ serves $page"
else
  fail "https://$page_host/ differs from $page"
fi
expect "http://$page_host/" 301 "https://$page_host/"
certificate "$page_host"

targets="$invite"
while read -r host target; do
  [ -n "$host" ] || continue
  expect "https://$host/" 302 "$target"
  expect "http://$host/" 301 "https://$host/"
  certificate "$host"
  case " $targets " in *" $target "*) ;; *) targets="$targets $target" ;; esac
done <<EOF
$redirects
EOF

for target in $targets; do
  expect "$target" 200
done
# Zulip shows an error page instead of the sign-up form for an invalid link.
if curl -s --max-time 15 "$invite" | grep -q '<title>Sign up'; then
  pass "$invite shows the Zulip sign-up form"
else
  fail "$invite does not show the Zulip sign-up form"
fi
expect "$blog" 200

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
