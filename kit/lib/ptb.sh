#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# ptb.sh — tiny fail-closed test helpers for Bash suites. Source it.
#   ptb_eq NAME WANT GOT        ptb_ok NAME CMD...      ptb_fails NAME CMD...
#   ptb_done                    exits non-zero if any failed OR if zero ran (DOG-01)
# A suite that runs no assertions is a failure, not a pass.
PTB_PASS=0; PTB_FAIL=0
ptb_eq()    { if [ "$2" = "$3" ]; then PTB_PASS=$((PTB_PASS+1)); else PTB_FAIL=$((PTB_FAIL+1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
ptb_ok()    { local n="$1"; shift; if "$@" >/dev/null 2>&1; then PTB_PASS=$((PTB_PASS+1)); else PTB_FAIL=$((PTB_FAIL+1)); echo "FAIL $n: expected success: $*"; fi; }
ptb_fails() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then PTB_FAIL=$((PTB_FAIL+1)); echo "FAIL $n: expected failure (negative control passed): $*"; else PTB_PASS=$((PTB_PASS+1)); fi; }
ptb_done()  {
  echo "ptb: $PTB_PASS passed, $PTB_FAIL failed"
  [ "$PTB_FAIL" -eq 0 ] || exit 1
  [ "$PTB_PASS" -gt 0 ] || { echo "ptb: NO ASSERTIONS RAN - that is a failure, not a pass" >&2; exit 2; }
  exit 0
}
