#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# The honesty lint: fail if any proof escape hatch appears in Idris2 sources.
#
# WHY THIS IS A SCRIPT AND NOT TWO COPIES OF A GREP
# -------------------------------------------------
# Until 2026-08-07 this check existed twice — once in `Justfile:lint` and once
# inline in `.github/workflows/ci.yml` — and BOTH copies grepped only four of
# the six patterns that `.machine_readable/descriptiles/AGENTIC.a2ml` bans. `idris_crash`
# and hole syntax (`?name`) were prohibited by the manifest and matched by
# neither gate. Two copies of a rule drift from the rule and from each other;
# there is now one copy, and both callers invoke it.
#
# Exit codes follow the check-toolchain-pins.sh convention:
#   0  no escape hatches found
#   1  at least one escape hatch found
#   2  the scan could not be performed (a skip is NOT a pass)

set -uo pipefail

SCOPE=(src tests benchmarks integrations templates corpus)

# Keep in lockstep with AGENTIC.a2ml `banned-proof-escape-hatches`.
# `?hole` is matched as Idris2 hole syntax generally — `?` followed by an
# identifier, in term position — not as the literal string "?hole".
LITERAL_PATTERNS='believe_me|assert_total|assert_smaller|%partial|%default (partial|covering)|unsafePerformIO|idris_crash'
# A `partial` modifier on a declaration opts that function out of totality
# checking. Function-level `covering` stays allowed: it is the honest marker
# for I/O entry points that read files (readFile consumes fuel until EOF), and
# the totality checker still verifies coverage.
PARTIAL_DECL='^[[:space:]]*((public )?export[[:space:]]+|private[[:space:]]+)?partial([[:space:]]|$)'
HOLE_PATTERN='(^|[[:space:](=,[])\?[a-zA-Z_][a-zA-Z0-9_'"'"']*'

missing=0
for dir in "${SCOPE[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "check-escape-hatches: scope directory '$dir' does not exist" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "FAIL: NO SCAN WAS PERFORMED — the scan scope is incomplete." >&2
  echo "      A missing directory is not a clean result." >&2
  exit 2
fi

echo "Scanning for proof escape hatches in: ${SCOPE[*]}"

hits=0

if grep -rnE "$LITERAL_PATTERNS" "${SCOPE[@]}" --include="*.idr"; then
  hits=1
fi

if grep -rnE "$HOLE_PATTERN" "${SCOPE[@]}" --include="*.idr"; then
  hits=1
fi

if grep -rnE "$PARTIAL_DECL" "${SCOPE[@]}" --include="*.idr"; then
  hits=1
fi

# Every Idris2 file must declare `%default total`, so a new function is total
# unless it says otherwise. Without this, a file that omits the pragma is
# silently `covering`, and nothing above would notice.
while IFS= read -r f; do
  if ! grep -qE '^%default total([[:space:]]|$)' "$f"; then
    echo "$f: missing '%default total'"
    hits=1
  fi
done < <(find "${SCOPE[@]}" -name '*.idr' -type f)

if [ "$hits" -ne 0 ]; then
  echo
  echo "FAIL: proof escape hatch found. Actually-Proven content may not use these."
  echo "      Banned: believe_me, assert_total, assert_smaller, %partial,"
  echo "              %default partial|covering, partial declarations,"
  echo "              unsafePerformIO, idris_crash, and hole syntax (?name)."
  echo "      Required: '%default total' in every .idr file."
  exit 1
fi

echo "OK: no proof escape hatches in ${SCOPE[*]}"
