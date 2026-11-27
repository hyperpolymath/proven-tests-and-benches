#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# bench-pipeline.sh — latency of the estate pipeline-tail tools (panic-attack, hypatia,
# echidna, verisim). Prints sixsigma TSV rows: pipeline-<tool>-latency-ms <TAB> ms <TAB> lower <TAB> abs_max
# usage: bench-pipeline.sh [--abs-max MS] TOOL [-- ARGS...]   (TOOL is one of the four, or any
#   executable name for a stub). Best of 3 runs. A tool that is absent or fails is exit 2
#   "NO CHECK PERFORMED", never a row: a missing tool must not look like a fast one.
set -u
absmax=60000
if [[ "${1:-}" == --abs-max ]]; then [[ $# -ge 2 ]] || { echo "NO CHECK PERFORMED: usage: bench-pipeline.sh [--abs-max MS] TOOL [-- ARGS...]" >&2; exit 2; }; absmax="$2"; shift 2; fi
tool="${1:-}"
[[ -n "$tool" ]] || { echo "NO CHECK PERFORMED: usage: bench-pipeline.sh [--abs-max MS] TOOL [-- ARGS...]" >&2; exit 2; }
shift; [[ "${1:-}" == -- ]] && shift
[[ "$absmax" =~ ^[0-9]+$ ]] || { echo "NO CHECK PERFORMED: --abs-max must be an integer" >&2; exit 2; }
command -v "$tool" >/dev/null 2>&1 || { echo "NO CHECK PERFORMED: $tool not installed" >&2; exit 2; }
best=""
for _ in 1 2 3; do
  a=$(date +%s%N)
  "$tool" "$@" >/dev/null 2>&1 || { echo "NO CHECK PERFORMED: $tool failed, no measurement" >&2; exit 2; }
  b=$(date +%s%N)
  d=$(( (b - a) / 1000000 )); [[ "$d" -ge 1 ]] || d=1
  [[ -z "$best" ]] || [[ "$d" -lt "$best" ]] && best="$d"
done
printf 'pipeline-%s-latency-ms\t%s\tlower\t%s\n' "${tool##*/}" "$best" "$absmax"
