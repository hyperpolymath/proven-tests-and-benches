#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# enum-drift.sh — CR-1: two enums (e.g. a Rust mirror and its source) list the same variants.
# Usage: enum-drift.sh --a FILE --a-re ERE --b FILE --b-re ERE
#   Variants are what `grep -oE ERE` prints from each file (one token per match).
# Exit: 0 same set; 1 drift (names the differences); 2 no check performed (missing file or empty extraction).
set -u
a=""; b=""; are=""; bre=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --a) a="$2"; shift 2 ;; --b) b="$2"; shift 2 ;;
    --a-re) are="$2"; shift 2 ;; --b-re) bre="$2"; shift 2 ;;
    *) echo "NO CHECK PERFORMED: unknown arg $1" >&2; exit 2 ;;
  esac
done
[[ -r "$a" && -r "$b" && -n "$are" && -n "$bre" ]] || { echo "NO CHECK PERFORMED: usage: need --a --a-re --b --b-re" >&2; exit 2; }
ta="$(mktemp)" && tb="$(mktemp)" || { echo "NO CHECK PERFORMED: mktemp failed" >&2; exit 2; }
trap 'rm -f "$ta" "$tb"' EXIT
grep -oE -- "$are" "$a" | sort -u > "$ta"; grep -oE -- "$bre" "$b" | sort -u > "$tb"
[[ -s "$ta" && -s "$tb" ]] || { echo "NO CHECK PERFORMED: an extraction was empty (wrong regex?)" >&2; exit 2; }
if diff "$ta" "$tb" >&2; then echo "OK: $(wc -l < "$ta") variants agree"; else echo "VIOLATION: enum drift (< only in A, > only in B)" >&2; exit 1; fi
