#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# e2e.sh — end-to-end (E2E). Drive the real entry point with real input; check stdout and exit code.
#   e2e.sh [--stdin FILE] [--expect-exit N] --expect REGEX [--timeout SECS] -- CMD [ARGS...]
# Pass 0: exit code is N (default 0), stdout non-empty and matches REGEX. Fail 1: otherwise.
# Exit 2: nothing run (CMD missing, bad usage, unreadable stdin file).
set -u
in=""; want=0; re=""; t=30
while [[ $# -gt 0 ]]; do case "$1" in --stdin) in="$2"; shift 2 ;; --expect-exit) want="$2"; shift 2 ;; --expect) re="$2"; shift 2 ;; --timeout) t="$2"; shift 2 ;; --) shift; break ;; *) break ;; esac; done
[[ -n "$re" ]] && [[ $# -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: e2e.sh --expect REGEX -- CMD..." >&2; exit 2; }
case "$want" in ''|*[!0-9]*) echo "NO CHECK PERFORMED: --expect-exit must be a number" >&2; exit 2 ;; *) ;; esac
command -v "$1" >/dev/null 2>&1 || [[ -x "$1" ]] || { echo "NO CHECK PERFORMED: $1 not found" >&2; exit 2; }
[[ -z "$in" ]] || [[ -r "$in" ]] || { echo "NO CHECK PERFORMED: stdin file $in unreadable" >&2; exit 2; }
if [[ -n "$in" ]]; then out=$(timeout -k 5 "$t" "$@" <"$in" 2>/dev/null); else out=$(timeout -k 5 "$t" "$@" </dev/null 2>/dev/null); fi; rc=$?
[[ "$rc" -eq "$want" ]] || { echo "E2E FAIL: exit $rc, wanted $want (124 = timeout): $*" >&2; exit 1; }
[[ -n "$out" ]] || { echo "E2E FAIL: empty stdout: $*" >&2; exit 1; }
printf '%s' "$out" | grep -Eq -- "$re" || { echo "E2E FAIL: stdout does not match /$re/" >&2; exit 1; }
echo "E2E OK: $*"
