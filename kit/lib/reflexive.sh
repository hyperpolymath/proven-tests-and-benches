#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# reflexive.sh — reflexive/determinism check (REF). A command must give the same answer run twice,
# and (with --idempotent) feeding its own output back through it must be a fixed point.
#   reflexive.sh [--idempotent] -- CMD [ARGS...]     (--idempotent: CMD reads stdin, writes stdout)
# Pass 0. Fail 1: two runs differ, or f(f(x)) != f(x). Exit 2: nothing checked.
set -u
idem=0
while [[ $# -gt 0 ]]; do case "$1" in --idempotent) idem=1; shift ;; --) shift; break ;; *) break ;; esac; done
[[ $# -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: reflexive.sh [--idempotent] -- CMD..." >&2; exit 2; }
command -v "$1" >/dev/null 2>&1 || [[ -x "$1" ]] || { echo "NO CHECK PERFORMED: $1 not found" >&2; exit 2; }
d=$(mktemp -d) || { echo "NO CHECK PERFORMED: mktemp failed" >&2; exit 2; }; trap 'rm -rf "$d"' EXIT
if [[ "$idem" -eq 1 ]]; then
  inp="$d/in"; cat >"$inp"
  "$@" <"$inp" >"$d/a" 2>/dev/null || { echo "NO CHECK PERFORMED: command failed: $*" >&2; exit 2; }
  "$@" <"$d/a" >"$d/b" 2>/dev/null || { echo "REFLEXIVE FAIL: command failed on its own output: $*" >&2; exit 1; }
  cmp -s "$d/a" "$d/b" || { echo "REFLEXIVE FAIL: not idempotent: $*" >&2; exit 1; }
else
  "$@" >"$d/a" 2>/dev/null || { echo "NO CHECK PERFORMED: command failed: $*" >&2; exit 2; }
  "$@" >"$d/b" 2>/dev/null || { echo "REFLEXIVE FAIL: second run failed: $*" >&2; exit 1; }
  cmp -s "$d/a" "$d/b" || { echo "REFLEXIVE FAIL: nondeterministic output: $*" >&2; exit 1; }
fi
echo "REFLEXIVE OK: $*"
