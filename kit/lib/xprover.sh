#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# xprover.sh — cross-prover proof regression (sweep 4). The same claims must still be proved by
# every prover that is meant to agree (e.g. Agda, Idris2, Lean).
#   xprover.sh --claims FILE --prover "NAME=COMMAND" [--prover "NAME=COMMAND"]... [--min N]
# Each COMMAND (a shell snippet) must succeed and print each claim id. Needs at least --min
# provers (default 2): one prover is proofreg.sh, not a cross-check.
# Exit: 0 every prover proves every claim; 1 a prover dropped a claim or failed (named);
#       2 no check performed (usage, fewer than --min provers, claims unreadable or empty).
set -u
cl=""; min=2; names=(); cmds=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claims) cl="${2:-}"; shift 2 ;;
    --min) min="${2:-}"; shift 2 ;;
    --prover) spec="${2:-}"; [[ "$spec" == *=* ]] || { echo "NO CHECK PERFORMED: usage: --prover NAME=COMMAND" >&2; exit 2; }
      names+=("${spec%%=*}"); cmds+=("${spec#*=}"); shift 2 ;;
    *) echo "NO CHECK PERFORMED: usage: xprover.sh --claims FILE --prover NAME=COMMAND ..." >&2; exit 2 ;;
  esac
done
[[ "$min" =~ ^[0-9]+$ ]] || { echo "NO CHECK PERFORMED: --min must be a number" >&2; exit 2; }
[[ -r "$cl" ]] || { echo "NO CHECK PERFORMED: usage: claims file unreadable" >&2; exit 2; }
claims="$(grep -Ev '^[[:space:]]*(#|$)' "$cl")"
[[ -n "$claims" ]] || { echo "NO CHECK PERFORMED: claims file has no claims" >&2; exit 2; }
[[ "${#names[@]}" -ge "$min" ]] || { echo "NO CHECK PERFORMED: ${#names[@]} prover(s), need at least $min for a cross-check" >&2; exit 2; }
bad=0
for i in "${!names[@]}"; do
  out="$(bash -c "${cmds[$i]}" 2>/dev/null)" || { echo "XPROVER FAIL: ${names[$i]} run failed" >&2; bad=1; continue; }
  while IFS= read -r c; do
    grep -qFx -- "$c" <<<"$out" || { echo "XPROVER FAIL: ${names[$i]} no longer proves: $c" >&2; bad=1; }
  done <<<"$claims"
done
[[ "$bad" -eq 0 ]] || exit 1
echo "XPROVER OK: ${#names[@]} provers agree on all claims"
