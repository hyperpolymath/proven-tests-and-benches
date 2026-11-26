#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# sixsigma.sh — language-agnostic Six Sigma classifier for benchmark results
# (TESTING-TAXONOMY.adoc Part IV). Classifies each benchmark as
# Unacceptable / Acceptable / Ordinary / Extraordinary against a baseline that
# is the arithmetic MEAN of the last N (default 10) main-branch runs.
#
# Usage:
#   sixsigma.sh [--window N] [--require-full-window] [--json] \
#               --baseline-dir DIR  RESULTS.tsv
#
# RESULTS.tsv and every baseline file in DIR (*.tsv): tab-separated,
#   name <TAB> value <TAB> direction [<TAB> abs_max]
#   direction  lower  (latency, memory, startup, build, energy, ffi: smaller is better)
#              higher (throughput: larger is better)
#   abs_max    optional absolute ceiling (lower) / floor (higher); breach = Unacceptable
# Baseline files are ordered by name; the last N are used (the fetcher writes
# NNNNNNNN-<run-id>.tsv, so name order is run order).
#
# Classes (regression is signed so that positive = worse, whatever the direction):
#   Unacceptable   regression > 50%, or absolute threshold breached      exit 1 (hard fail)
#   Acceptable     regression 20%..50% inclusive                         exit 3 (soft fail)
#   Ordinary       regression < 20% and improvement <= 20%               exit 0
#   Extraordinary  improvement > 20% (real or measurement error: flag)   exit 0 (flagged)
# Overall exit is the worst class. A benchmark with no baseline, a malformed or
# non-positive value, an empty baseline dir, or (with --require-full-window)
# fewer than N baseline files exits 2: NO CHECK PERFORMED, never a pass.
set -u
window=10; full=0; json=0; bdir=""; res=""
while [ $# -gt 0 ]; do
  case "$1" in
    --window) window="$2"; shift 2 ;;
    --require-full-window) full=1; shift ;;
    --json) json=1; shift ;;
    --baseline-dir) bdir="$2"; shift 2 ;;
    -h|--help) sed -n 2,30p "$0"; exit 0 ;;
    *) res="$1"; shift ;;
  esac
done
nocheck() { echo "NO CHECK PERFORMED: $1" >&2; exit 2; }
[ -n "$res" ] && [ -r "$res" ] || nocheck "results file missing or unreadable: ${res:-<none>}"
[ -n "$bdir" ] && [ -d "$bdir" ] || nocheck "baseline dir missing: ${bdir:-<none>}"
case "$window" in ''|*[!0-9]*|0) nocheck "bad --window $window" ;; esac
mapfile -t files < <(ls -1 "$bdir"/*.tsv 2>/dev/null | sort | tail -n "$window")
[ "${#files[@]}" -gt 0 ] || nocheck "no baseline *.tsv files in $bdir (no baseline is not a pass)"
if [ "$full" -eq 1 ] && [ "${#files[@]}" -lt "$window" ]; then
  nocheck "only ${#files[@]} baseline runs, --require-full-window wants $window"
fi
[ "${#files[@]}" -ge "$window" ] || echo "note: baseline uses ${#files[@]} of $window runs" >&2

awk -F'\t' -v json="$json" -v nfiles="${#files[@]}" '
function numeric(s) { return s ~ /^[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/ }
function rank(c) { return c=="Unacceptable"?4 : c=="Acceptable"?3 : c=="Extraordinary"?2 : 1 }
FNR==1 { fidx++ }
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
{
  if (!numeric($2) || $2+0 <= 0 || ($3 != "lower" && $3 != "higher")) { malformed = malformed "\n  " FILENAME ":" FNR ": " $0; next }
  if (FILENAME == ARGV[1]) { cur[$1] = $2+0; dir[$1] = $3; absmax[$1] = ($4 != "" && numeric($4)) ? $4+0 : ""; order[++n] = $1 }
  else { sum[$1] += $2; sq[$1] += $2*$2; cnt[$1]++ }
}
END {
  if (malformed != "") { print "NO CHECK PERFORMED: malformed rows:" malformed > "/dev/stderr"; exit 2 }
  if (n == 0) { print "NO CHECK PERFORMED: results file has no benchmark rows" > "/dev/stderr"; exit 2 }
  worst = 1; names[1]="Ordinary"; names[2]="Extraordinary"; names[3]="Acceptable"; names[4]="Unacceptable"
  if (json) printf "["
  for (i = 1; i <= n; i++) {
    b = order[i]
    if (!(b in cnt)) { print "NO CHECK PERFORMED: benchmark \"" b "\" has no baseline rows" > "/dev/stderr"; exit 2 }
    mean = sum[b] / cnt[b]; var = sq[b]/cnt[b] - mean*mean; if (var < 0) var = 0; sigma = sqrt(var)
    reg = (dir[b] == "lower") ? (cur[b] - mean) / mean : (mean - cur[b]) / mean   # positive = worse
    cls = "Ordinary"
    if (reg > 0.5) cls = "Unacceptable"
    else if (reg >= 0.2) cls = "Acceptable"
    else if (reg < -0.2) cls = "Extraordinary"
    why = ""
    if (absmax[b] != "") {
      breach = (dir[b] == "lower") ? (cur[b] > absmax[b]) : (cur[b] < absmax[b])
      if (breach) { cls = "Unacceptable"; why = "absolute threshold breached" }
    }
    if (rank(cls) > worst) worst = rank(cls)
    if (json) printf "%s{\"name\":\"%s\",\"value\":%s,\"baseline_mean\":%.6g,\"sigma\":%.6g,\"baseline_runs\":%d,\"regression_pct\":%.2f,\"class\":\"%s\"}", (i>1?",":""), b, cur[b], mean, sigma, cnt[b], reg*100, cls
    else printf "%-32s cur=%-12.6g base=%-12.6g sigma=%-10.4g n=%-2d regression=%+7.2f%%  %s%s\n", b, cur[b], mean, sigma, cnt[b], reg*100, cls, (why!="" ? "  (" why ")" : "")
  }
  if (json) printf "]\n"
  else printf "overall: %s\n", names[worst]
  exit (names[worst]=="Unacceptable") ? 1 : (names[worst]=="Acceptable") ? 3 : 0
}' "$res" "${files[@]}"
