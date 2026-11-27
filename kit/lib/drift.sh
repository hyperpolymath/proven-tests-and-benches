#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# drift.sh — coupling/drift-freedom (CDF). Two representations that must agree, do.
#   drift.sh --generated-by CMD... --committed FILE     (CMD regenerates FILE's content on stdout)
# Pass 0: regenerated output equals the committed file. Fail 1: drifted. Exit 2: nothing checked.
set -u
c=""; cmd=()
while [ $# -gt 0 ]; do case "$1" in --committed) c="$2"; shift 2 ;; --generated-by) shift; while [ $# -gt 0 ] && [ "$1" != "--committed" ]; do cmd+=("$1"); shift; done ;; *) break ;; esac; done
[ -n "$c" ] && [ "${#cmd[@]}" -gt 0 ] || { echo "NO CHECK PERFORMED: usage: drift.sh --generated-by CMD... --committed FILE" >&2; exit 2; }
[ -s "$c" ] || { echo "NO CHECK PERFORMED: committed file $c missing or empty" >&2; exit 2; }
command -v "${cmd[0]}" >/dev/null 2>&1 || [ -x "${cmd[0]}" ] || { echo "NO CHECK PERFORMED: ${cmd[0]} not found" >&2; exit 2; }
out=$(mktemp) || { echo "NO CHECK PERFORMED: mktemp failed" >&2; exit 2; }; trap 'rm -f "$out"' EXIT
"${cmd[@]}" >"$out" 2>/dev/null || { echo "NO CHECK PERFORMED: generator failed: ${cmd[*]}" >&2; exit 2; }
[ -s "$out" ] || { echo "NO CHECK PERFORMED: generator produced no output" >&2; exit 2; }
if diff -u "$c" "$out" >&2; then echo "DRIFT OK: $c"; else echo "DRIFT FAIL: $c is stale against ${cmd[*]}" >&2; exit 1; fi
