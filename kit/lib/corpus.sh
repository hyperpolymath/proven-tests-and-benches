#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# corpus.sh — CR-4: a shared fixture corpus that every consumer actually runs.
# Usage: corpus.sh --dir DIR [--min N] [--glob PATTERN] -- CMD...
#   CMD is run once per fixture with the fixture path appended; all must exit 0.
#   Fixtures must be non-empty. Fewer than --min (default 1) fixtures is a violation.
# Exit: 0 pass; 1 a fixture fails/empty or too few; 2 no check performed.
set -u
dir=""; min=1; glob="*"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;; --min) min="$2"; shift 2 ;; --glob) glob="$2"; shift 2 ;;
    --) shift; break ;; *) echo "NO CHECK PERFORMED: unknown arg $1" >&2; exit 2 ;;
  esac
done
[[ -d "$dir" && $# -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: need --dir DIR -- CMD..." >&2; exit 2; }
[[ "$min" =~ ^[0-9]+$ ]] || { echo "NO CHECK PERFORMED: --min must be a number" >&2; exit 2; }
n=0; bad=0
for f in "$dir"/$glob; do
  [[ -f "$f" ]] || continue
  n=$((n + 1))
  [[ -s "$f" ]] || { echo "VIOLATION: empty fixture $f" >&2; bad=1; continue; }
  "$@" "$f" >/dev/null 2>&1 || { echo "VIOLATION: consumer failed on $f" >&2; bad=1; }
done
[[ "$n" -ge "$min" ]] || { echo "VIOLATION: $n fixture(s) in $dir, need $min" >&2; exit 1; }
[[ "$bad" -eq 0 ]] || exit 1
echo "OK: $n fixture(s) consumed"
