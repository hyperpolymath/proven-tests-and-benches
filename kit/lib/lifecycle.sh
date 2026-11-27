#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# lifecycle.sh — lifecycle (LCY). Setup, use and teardown, in order; teardown always runs.
#   lifecycle.sh [--setup CMD] --use CMD [--use CMD]... [--teardown CMD]
# Commands run through bash -c. A failed setup skips the uses; teardown runs regardless.
# Pass 0: every step succeeded. Fail 1: any step (teardown included) failed.
# Exit 2: nothing checked (no --use, usage).
set -u
setup=""; td=""; uses=()
while [[ $# -gt 0 ]]; do case "$1" in
  --setup) [[ $# -ge 2 ]] || break; setup="$2"; shift 2 ;;
  --use) [[ $# -ge 2 ]] || break; uses+=("$2"); shift 2 ;;
  --teardown) [[ $# -ge 2 ]] || break; td="$2"; shift 2 ;;
  *) break ;; esac; done
if [[ "${#uses[@]}" -eq 0 ]] || [[ $# -gt 0 ]]; then echo "NO CHECK PERFORMED: usage: lifecycle.sh [--setup CMD] --use CMD... [--teardown CMD]" >&2; exit 2; fi
bad=0
if [[ -n "$setup" ]] && ! bash -c "$setup" >/dev/null 2>&1; then echo "LIFECYCLE FAIL: setup failed" >&2; bad=1; fi
if [[ "$bad" -eq 0 ]]; then for u in "${uses[@]}"; do bash -c "$u" >/dev/null 2>&1 || { echo "LIFECYCLE FAIL: step failed: $u" >&2; bad=1; break; }; done; fi
if [[ -n "$td" ]] && ! bash -c "$td" >/dev/null 2>&1; then echo "LIFECYCLE FAIL: teardown failed" >&2; bad=1; fi
[[ "$bad" -eq 0 ]] && echo "LIFECYCLE OK" || exit 1
