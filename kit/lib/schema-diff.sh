#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# schema-diff.sh — CR-9: classify a change to an API/schema surface and gate it by semver.
# Usage: schema-diff.sh --old FILE --new FILE [--allow major|minor|patch]
#   FILEs list the public surface, one item per line. Removed item => major; added => minor; same => patch.
#   Prints the class. Fails if the class is higher than --allow (default patch).
# Exit: 0 within allowance; 1 exceeds it; 2 no check performed.
set -u
old=""; new=""; allow=patch
while [[ $# -gt 0 ]]; do
  case "$1" in
    --old) old="$2"; shift 2 ;; --new) new="$2"; shift 2 ;; --allow) allow="$2"; shift 2 ;;
    *) echo "NO CHECK PERFORMED: unknown arg $1" >&2; exit 2 ;;
  esac
done
[[ -r "$old" && -r "$new" ]] || { echo "NO CHECK PERFORMED: usage: need readable --old and --new" >&2; exit 2; }
case "$allow" in patch|minor|major) ;; *) echo "NO CHECK PERFORMED: --allow must be patch|minor|major" >&2; exit 2 ;; esac
[[ -s "$old" && -s "$new" ]] || { echo "NO CHECK PERFORMED: an empty surface file" >&2; exit 2; }
removed="$(comm -23 <(sort -u "$old") <(sort -u "$new") | wc -l)"
added="$(comm -13 <(sort -u "$old") <(sort -u "$new") | wc -l)"
cls=patch; [[ "$added" -gt 0 ]] && cls=minor; [[ "$removed" -gt 0 ]] && cls=major
rank() { case "$1" in patch) echo 0 ;; minor) echo 1 ;; major) echo 2 ;; *) echo 9 ;; esac; }
echo "class: $cls (removed $removed, added $added)"
[[ "$(rank "$cls")" -le "$(rank "$allow")" ]] || { echo "VIOLATION: $cls change exceeds allowed $allow" >&2; exit 1; }
