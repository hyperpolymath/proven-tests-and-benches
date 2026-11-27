#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# regression.sh — golden-output regression (REG). Output of CMD must equal a committed golden file.
#   regression.sh --golden FILE -- CMD [ARGS...]
# Pass 0: stdout identical to FILE. Fail 1: differs (a diff is printed). Exit 2: nothing checked
# (golden missing/empty, CMD missing or failing to run). There is deliberately NO --update flag:
# a golden is changed by a reviewed commit, never by the check itself.
set -u
g=""
while [[ $# -gt 0 ]]; do case "$1" in --golden) g="$2"; shift 2 ;; --) shift; break ;; *) break ;; esac; done
[[ -n "$g" ]] && [[ $# -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: regression.sh --golden FILE -- CMD..." >&2; exit 2; }
[[ -s "$g" ]] || { echo "NO CHECK PERFORMED: golden $g missing or empty" >&2; exit 2; }
command -v "$1" >/dev/null 2>&1 || [[ -x "$1" ]] || { echo "NO CHECK PERFORMED: $1 not found" >&2; exit 2; }
out=$(mktemp) || { echo "NO CHECK PERFORMED: mktemp failed" >&2; exit 2; }; trap 'rm -f "$out"' EXIT
"$@" >"$out" 2>/dev/null; rc=$?
[[ "$rc" -eq 0 ]] || { echo "REGRESSION FAIL: command exited $rc: $*" >&2; exit 1; }
if diff -u "$g" "$out" >&2; then echo "REGRESSION OK: $*"; else echo "REGRESSION FAIL: output differs from $g" >&2; exit 1; fi
