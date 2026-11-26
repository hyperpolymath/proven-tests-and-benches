#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# agda-prove.sh — step 1 of the owner's proof order: every Agda file must
# type-check with --safe --cubical-compatible, AND pass the doubt check.
# Full --cubical comes later (LATER.adoc), so it is deliberately NOT used here.
#
# Usage: agda-prove.sh [--allow FILE] PATH...
# Exit: 0 all proved and no doubts; 1 type error or doubt; 2 no check performed
# (no agda binary, no sources). Never 0 on absence.
set -u
export LC_ALL="${LC_ALL:-C.UTF-8}"
here="$(cd "$(dirname "$0")" && pwd)"
command -v agda >/dev/null || { echo "NO CHECK PERFORMED: agda not installed" >&2; exit 2; }
"$here/agda-doubt-check.sh" "$@"; d=$?
[ "$d" -eq 2 ] && exit 2
allowarg=(); paths=()
while [ $# -gt 0 ]; do case "$1" in --allow) shift 2 ;; *) paths+=("$1"); shift ;; esac; done
mapfile -t files < <(find "${paths[@]}" -type f \( -name '*.agda' -o -name '*.lagda' -o -name '*.lagda.md' \) | sort)
bad=0
for f in "${files[@]}"; do
  # --safe/--cubical-compatible on the command line AND (checked above) in the file
  if ! (cd "$(dirname "$f")" && agda --safe --cubical-compatible "$(basename "$f")" >/dev/null 2>&1); then
    echo "TYPE ERROR (or unprovable) under --safe --cubical-compatible: $f" >&2; bad=1
  fi
done
[ "$d" -eq 0 ] && [ "$bad" -eq 0 ] && { echo "PROVED: ${#files[@]} file(s) under --safe --cubical-compatible, no doubts"; exit 0; }
exit 1
