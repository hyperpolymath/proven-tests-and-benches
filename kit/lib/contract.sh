#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# contract.sh — contract/invariant (CTR). Run CMD; its stdout must satisfy every invariant.
#   contract.sh [--require REGEX]... [--forbid REGEX]... -- CMD...
# Pass 0: CMD succeeds, every --require matches, no --forbid matches. Fail 1: a violation.
# Exit 2: nothing checked (no invariants given, CMD missing, CMD errors, usage).
set -u
req=(); forb=(); cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --require) [[ $# -ge 2 ]] || break; req+=("$2"); shift 2 ;;
  --forbid)  [[ $# -ge 2 ]] || break; forb+=("$2"); shift 2 ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
[[ "${#cmd[@]}" -gt 0 ]] && [[ $(( ${#req[@]} + ${#forb[@]} )) -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: contract.sh [--require RE]... [--forbid RE]... -- CMD..." >&2; exit 2; }
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || { echo "NO CHECK PERFORMED: ${cmd[0]} not found" >&2; exit 2; }
out=$("${cmd[@]}" 2>/dev/null) || { echo "CONTRACT FAIL: command failed: ${cmd[*]}" >&2; exit 1; }
[[ -n "$out" ]] || { echo "NO CHECK PERFORMED: command produced no output to check" >&2; exit 2; }
bad=0
for r in "${req[@]}"; do grep -Eq -- "$r" <<<"$out" || { echo "CONTRACT FAIL: required /$r/ absent" >&2; bad=1; }; done
for r in "${forb[@]}"; do ! grep -Eq -- "$r" <<<"$out" || { echo "CONTRACT FAIL: forbidden /$r/ present" >&2; bad=1; }; done
[[ "$bad" -eq 0 ]] && echo "CONTRACT OK" || exit 1
