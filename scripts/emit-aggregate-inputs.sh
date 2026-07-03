#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Feed the proof-ladder files cited by Actually-Proven tests (from the JSON run
# report) into panic-attack's `aggregate`, which classifies each proof artifact
# (Closed/Holes/Refuted/Indeterminate) and folds it into a trust-tagged report.
#
# Semantic contract (see docs/INTEROP-PANIC-ATTACK.adoc):
#   * ONLY Actually-Proven ladder files are emitted — they are the only entries
#     backed by a real proof artifact. A ladder file is expected to classify
#     `Closed`; a `Holes`/`Refuted` verdict means a cited theorem is not actually
#     discharged, which is a genuine failure and exits non-zero.
#   * Provisionally-Proven and Unproven tests have NO proof artifact and are
#     deliberately not fed (Provisionally != Holes).
#
# Usage: emit-aggregate-inputs.sh <run-report.json> [panic-attack-binary]
set -euo pipefail

REPORT="${1:-build/report/proven-tests-report.json}"
PANIC_ATTACK="${2:-panic-attack}"

if [ ! -f "$REPORT" ]; then
  echo "error: run report not found: $REPORT" >&2
  echo "  run: ./build/exec/proven-tests --report $REPORT" >&2
  exit 2
fi

# Distinct proof_file paths from Actually-Proven entries' ladders.
extract_ladder_files() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.entries[]
             | select(.provenance == "Actually-Proven")
             | .proof_ladder[].proof_file
             | select(. != null)' "$REPORT" | sort -u
  else
    # jq-free fallback: pull "proof_file":"..." occurrences. Coarse but works
    # for our known-safe values (no escaping in file paths).
    grep -o '"proof_file":"[^"]*"' "$REPORT" \
      | sed 's/"proof_file":"//;s/"$//' | sort -u
  fi
}

mapfile -t LADDER_FILES < <(extract_ladder_files)

if [ "${#LADDER_FILES[@]}" -eq 0 ]; then
  echo "no Actually-Proven proof-ladder files cited in $REPORT — nothing to aggregate"
  exit 0
fi

echo "Actually-Proven proof-ladder files to aggregate:"
printf '  %s\n' "${LADDER_FILES[@]}"

if ! command -v "$PANIC_ATTACK" >/dev/null 2>&1; then
  echo "note: '$PANIC_ATTACK' not on PATH — listed the inputs but did not aggregate." >&2
  echo "      (build panic-attack, then re-run to fold these into a trust-tagged report)" >&2
  exit 0
fi

status=0
for f in "${LADDER_FILES[@]}"; do
  label="$(basename "$f" .idr)-ladder"
  echo "--- aggregate: $f (label=$label) ---"
  # panic-attack aggregate takes --label as PATH=NAME.
  if ! "$PANIC_ATTACK" aggregate --proof "$f" --label "$f=$label"; then
    echo "error: aggregate reported a non-Closed verdict for $f" >&2
    status=1
  fi
done
exit "$status"
