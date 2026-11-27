#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# compat.sh — compatibility (CMP). The same command must pass under every environment in a matrix.
#   compat.sh --matrix FILE -- CMD...
# FILE rows: NAME <TAB> VAR=val [VAR=val]...   (# comments, blanks ignored). Each row's variables
# are exported for one run of CMD. Pass 0: every row passes. Fail 1: a row fails (named).
# Exit 2: nothing checked (matrix missing/empty, bad row, CMD missing, usage).
set -u
mx=""; cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --matrix) [[ $# -ge 2 ]] || break; mx="$2"; shift 2 ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
nocheck() { echo "NO CHECK PERFORMED: $1" >&2; exit 2; }
[[ -n "$mx" ]] && [[ "${#cmd[@]}" -gt 0 ]] || nocheck "usage: compat.sh --matrix FILE -- CMD..."
[[ -r "$mx" ]] || nocheck "matrix $mx unreadable"
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || nocheck "${cmd[0]} not found"
rows=0; bad=0
while IFS=$'\t' read -r name vars; do
  [[ -n "${name//[[:space:]]/}" ]] && [[ "$name" != \#* ]] || continue
  [[ -n "$vars" ]] || nocheck "row $name has no VAR=val"
  rows=$((rows + 1)); envs=()
  for kv in $vars; do [[ "$kv" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]] || nocheck "row $name: bad assignment $kv"; envs+=("$kv"); done
  if env "${envs[@]}" "${cmd[@]}" >/dev/null 2>&1; then echo "COMPAT $name: pass"; else echo "COMPAT $name: FAIL" >&2; bad=1; fi
done <"$mx"
[[ "$rows" -gt 0 ]] || nocheck "matrix has no rows"
[[ "$bad" -eq 0 ]] || exit 1
