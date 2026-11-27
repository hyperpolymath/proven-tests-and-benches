#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# typesafe.sh — type-safe (TSF). The strict type check passes AND no escape hatches appear.
#   typesafe.sh --forbid REGEX --in PATH... [--] CHECK-CMD...
# Pass 0: CHECK-CMD succeeds and REGEX (e.g. 'believe_me|unsafeCoerce|assert_total') matches
# nothing under PATH. Fail 1: type check fails or an escape hatch is present.
# Exit 2: nothing checked (missing CMD/paths/regex, usage).
set -u
forb=""; paths=(); cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --forbid) [[ $# -ge 2 ]] || break; forb="$2"; shift 2 ;;
  --in) shift; while [[ $# -gt 0 ]] && [[ "$1" != "--" ]] && [[ "$1" != --* ]]; do paths+=("$1"); shift; done ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
[[ -n "$forb" ]] && [[ "${#paths[@]}" -gt 0 ]] && [[ "${#cmd[@]}" -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: typesafe.sh --forbid RE --in PATH... -- CHECK-CMD..." >&2; exit 2; }
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || { echo "NO CHECK PERFORMED: ${cmd[0]} not found" >&2; exit 2; }
for p in "${paths[@]}"; do [[ -e "$p" ]] || { echo "NO CHECK PERFORMED: path $p missing" >&2; exit 2; }; done
bad=0
"${cmd[@]}" >/dev/null 2>&1 || { echo "TYPESAFE FAIL: type check failed: ${cmd[*]}" >&2; bad=1; }
if grep -rEn --binary-files=without-match -- "$forb" "${paths[@]}" >&2; then echo "TYPESAFE FAIL: escape hatch /$forb/ present" >&2; bad=1; fi
[[ "$bad" -eq 0 ]] && echo "TYPESAFE OK" || exit 1
