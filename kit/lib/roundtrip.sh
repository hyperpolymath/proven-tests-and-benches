#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# roundtrip.sh — CR-3 / CR-8: encode/decode bijection over sample inputs.
# Usage: roundtrip.sh --encode CMD --decode CMD -- FILE...
#   CMDs are shell snippets reading stdin, writing stdout. For each FILE:
#   decode(encode(x)) == x  and  encode(decode(encode(x))) == encode(x).
# Exit: 0 all roundtrip; 1 a file does not; 2 no check performed (no files, command failed to run).
set -u
enc=""; dec=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --encode) enc="$2"; shift 2 ;; --decode) dec="$2"; shift 2 ;;
    --) shift; break ;; *) echo "NO CHECK PERFORMED: unknown arg $1" >&2; exit 2 ;;
  esac
done
[[ -n "$enc" && -n "$dec" && $# -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: need --encode --decode -- FILE..." >&2; exit 2; }
t="$(mktemp -d)" || { echo "NO CHECK PERFORMED: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$t"' EXIT
bad=0
for f in "$@"; do
  [[ -r "$f" ]] || { echo "NO CHECK PERFORMED: $f unreadable" >&2; exit 2; }
  bash -c "$enc" < "$f" > "$t/e1" 2>/dev/null || { echo "VIOLATION: encode failed on $f" >&2; bad=1; continue; }
  bash -c "$dec" < "$t/e1" > "$t/d1" 2>/dev/null || { echo "VIOLATION: decode failed on $f" >&2; bad=1; continue; }
  cmp -s "$f" "$t/d1" || { echo "VIOLATION: decode(encode(x)) != x for $f" >&2; bad=1; continue; }
  bash -c "$enc" < "$t/d1" > "$t/e2" 2>/dev/null
  cmp -s "$t/e1" "$t/e2" || { echo "VIOLATION: encoding not canonical for $f" >&2; bad=1; }
done
[[ "$bad" -eq 0 ]] || exit 1
echo "OK: $# input(s) roundtrip"
