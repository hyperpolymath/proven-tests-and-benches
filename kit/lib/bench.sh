#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# bench.sh — baselined benchmark (B-LAT B-THR B-MEM B-STA B-BLD B-ENG B-FFI).
#   bench.sh --kind ID --baseline-dir DIR [--window N] [--require-full-window] -- CMD...
# CMD prints sixsigma TSV rows (name <TAB> value <TAB> lower|higher [<TAB> abs_max]) on stdout.
# They are classified against the mean of the last N (default 10) baseline runs in DIR by
# benchmarks/sixsigma/sixsigma.sh. Exit codes are sixsigma's: 0 Ordinary/Extraordinary,
# 3 Acceptable (soft fail), 1 Unacceptable, 2 no check performed (never a pass).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
sixs="$here/../../benchmarks/sixsigma/sixsigma.sh"
kind=""; bdir=""; opts=(); cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --kind) [[ $# -ge 2 ]] || break; kind="$2"; shift 2 ;;
  --baseline-dir) [[ $# -ge 2 ]] || break; bdir="$2"; shift 2 ;;
  --window) [[ $# -ge 2 ]] || break; opts+=(--window "$2"); shift 2 ;;
  --require-full-window) opts+=(--require-full-window); shift ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
nocheck() { echo "NO CHECK PERFORMED: $1" >&2; exit 2; }
[[ -n "$kind" ]] && [[ -n "$bdir" ]] && [[ "${#cmd[@]}" -gt 0 ]] || nocheck "usage: bench.sh --kind ID --baseline-dir DIR -- CMD..."
case " B-LAT B-THR B-MEM B-STA B-BLD B-ENG B-FFI " in *" $kind "*) ;; *) nocheck "unknown bench kind $kind" ;; esac
[[ -x "$sixs" ]] || nocheck "classifier $sixs missing"
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || nocheck "${cmd[0]} not found"
res=$(mktemp) || nocheck "mktemp failed"; trap 'rm -f "$res"' EXIT
"${cmd[@]}" >"$res" 2>/dev/null || nocheck "bench command failed: ${cmd[*]}"
echo "bench kind: $kind"
"$sixs" "${opts[@]}" --baseline-dir "$bdir" "$res"
