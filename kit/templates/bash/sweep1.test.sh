#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Sweep-1 template for Bash subjects: UT, SMK, BLD, P2P. ADAPT: set SUBJECT.
# Run: bash sweep1.test.sh   (exit 0 pass, 1 fail, 2 nothing ran)
here="$(cd "$(dirname "$0")" && pwd)"
. "${PTB_LIB:-$here/../../lib}/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# --- demo subject (ADAPT: replace by sourcing/running the real script) --------
cat > "$tmp/subject.sh" <<'S'
#!/usr/bin/env bash
case "${1:-}" in --version) echo "subject 1.0";; upper) tr a-z A-Z <<<"$2";; *) echo "usage: subject (--version|upper TEXT)" >&2; exit 64;; esac
S
chmod +x "$tmp/subject.sh"; SUBJECT="$tmp/subject.sh"
# --- UT: each public command, each error branch ---------------------------------
ptb_eq    UT-upper               "ABC"  "$("$SUBJECT" upper abc)"
ptb_fails UT-unknown-cmd-fails   "$SUBJECT" bogus
# --- SMK ------------------------------------------------------------------------
ptb_ok    SMK-version            "${PTB_LIB:-$here/../../lib}/smoke.sh" --expect '^subject [0-9]' -- "$SUBJECT" --version
# --- BLD: the "build" of a script is syntax-check + executable bit ---------------
ptb_ok    BLD-syntax             bash -n "$SUBJECT"
ptb_ok    BLD-executable         test -x "$SUBJECT"
ptb_fails BLD-negative-control   bash -n <(echo 'if then fi')
# --- P2P: producer | consumer over a pipe (one seam, double at far end only) -----
ptb_eq    P2P-pipe-roundtrip     "ABC"  "$(printf 'abc\n' | while read -r l; do "$SUBJECT" upper "$l"; done)"
ptb_done
