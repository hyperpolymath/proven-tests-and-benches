#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# decay.sh — CR-10: stale fixture / baseline alarm.
# Usage: decay.sh [--max-days N] [--now EPOCH] PATH...
#   Every file under PATHs must have been modified within N days (default 90; use 30 for bench baselines).
# Exit: 0 fresh; 1 stale file(s); 2 no check performed (no paths, missing path, no files found).
set -u
max=90; now="$(date +%s)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-days) max="$2"; shift 2 ;; --now) now="$2"; shift 2 ;;
    --) shift; break ;; -*) echo "NO CHECK PERFORMED: unknown arg $1" >&2; exit 2 ;; *) break ;;
  esac
done
[[ "$max" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]] || { echo "NO CHECK PERFORMED: numeric --max-days/--now" >&2; exit 2; }
[[ $# -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: no paths" >&2; exit 2; }
n=0; stale=0
for p in "$@"; do
  [[ -e "$p" ]] || { echo "NO CHECK PERFORMED: $p missing" >&2; exit 2; }
  while IFS= read -r f; do
    n=$((n + 1)); mt="$(stat -c %Y "$f")"; age=$(( (now - mt) / 86400 ))
    [[ "$age" -le "$max" ]] || { echo "VIOLATION: $f is $age days old (max $max)" >&2; stale=1; }
  done < <(find "$p" -type f)
done
[[ "$n" -gt 0 ]] || { echo "NO CHECK PERFORMED: no files under the paths" >&2; exit 2; }
[[ "$stale" -eq 0 ]] || exit 1
echo "OK: $n file(s) within $max days"
