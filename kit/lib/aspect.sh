#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# aspect.sh — the 14 quality aspects (DEP SEC USA IOP SAF PER FUN VER ACC MNT PRI OBS RPR PRT).
#   aspect.sh --map FILE ASPECT...        FILE rows: ASPECT <TAB> command | na:<reason>
# Runs the command mapped to each ASPECT. Pass 0: every named aspect passed or is declared
# na with a reason. Fail 1: an aspect's command failed. Exit 2: nothing checked (unknown aspect
# id, aspect unmapped, empty na reason, missing map, no aspects named, usage).
set -u
map=""; asp=()
while [[ $# -gt 0 ]]; do case "$1" in
  --map) [[ $# -ge 2 ]] || break; map="$2"; shift 2 ;;
  *) asp+=("$1"); shift ;; esac; done
[[ -n "$map" ]] && [[ "${#asp[@]}" -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: aspect.sh --map FILE ASPECT..." >&2; exit 2; }
[[ -r "$map" ]] || { echo "NO CHECK PERFORMED: map $map unreadable" >&2; exit 2; }
valid=" DEP SEC USA IOP SAF PER FUN VER ACC MNT PRI OBS RPR PRT "
bad=0
for a in "${asp[@]}"; do
  [[ "$valid" == *" $a "* ]] || { echo "NO CHECK PERFORMED: unknown aspect $a" >&2; exit 2; }
  line=$(awk -F'\t' -v a="$a" '$1==a {print $2; exit}' "$map")
  [[ -n "$line" ]] || { echo "NO CHECK PERFORMED: aspect $a unmapped" >&2; exit 2; }
  if [[ "$line" == na:* ]]; then
    [[ -n "${line#na:}" ]] && [[ "${line#na:}" != " " ]] || { echo "NO CHECK PERFORMED: aspect $a na without reason" >&2; exit 2; }
    echo "ASPECT $a: na (${line#na:})"; continue
  fi
  if bash -c "$line" >/dev/null 2>&1; then echo "ASPECT $a: pass"; else echo "ASPECT $a: FAIL" >&2; bad=1; fi
done
[[ "$bad" -eq 0 ]] || exit 1
