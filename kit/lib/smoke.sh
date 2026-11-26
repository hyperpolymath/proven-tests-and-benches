#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# smoke.sh — language-agnostic smoke test (SMK). The built artefact starts,
# answers, and exits cleanly within a time limit.
#   smoke.sh [--timeout SECS] --expect REGEX -- CMD [ARGS...]
# Pass: exit 0, output non-empty AND matches REGEX. Fail 1: otherwise.
# Exit 2: nothing was run (CMD missing / not executable): absence is not a pass.
set -u
t=10; re=""
while [ $# -gt 0 ]; do case "$1" in --timeout) t="$2"; shift 2 ;; --expect) re="$2"; shift 2 ;; --) shift; break ;; *) break ;; esac; done
[ -n "$re" ] && [ $# -gt 0 ] || { echo "NO CHECK PERFORMED: usage: smoke.sh --expect REGEX -- CMD..." >&2; exit 2; }
command -v "$1" >/dev/null 2>&1 || [ -x "$1" ] || { echo "NO CHECK PERFORMED: $1 not found" >&2; exit 2; }
out=$(timeout "$t" "$@" 2>&1); rc=$?
[ "$rc" -eq 0 ] || { echo "SMOKE FAIL: exit $rc (124 = timeout): $*" >&2; exit 1; }
[ -n "$out" ] || { echo "SMOKE FAIL: empty output: $*" >&2; exit 1; }
printf '%s' "$out" | grep -Eq -- "$re" || { echo "SMOKE FAIL: output does not match /$re/: $out" >&2; exit 1; }
echo "SMOKE OK: $*"
