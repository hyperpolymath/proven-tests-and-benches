#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# bench-kit.sh — benchmark targets for the kit itself. Prints sixsigma TSV rows on stdout:
#   name <TAB> value <TAB> lower|higher <TAB> abs_max
# usage: bench-kit.sh [KIND]    KIND one of B-LAT B-THR B-MEM B-STA B-BLD (default: all)
# B-ENG and B-FFI are N/A for the kit (no energy counter, no FFI surface); see .proven/coverage.tsv.
# Each value is >= 1 (a zero reading is a measurement failure, not a result). Exit 2 = no
# measurement made. Run these on the same runner class as the baseline: values are wall-clock.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
kind="${1:-all}"
case "$kind" in all|B-LAT|B-THR|B-MEM|B-STA|B-BLD) ;; *) echo "NO CHECK PERFORMED: unsupported kind $kind" >&2; exit 2 ;; esac
tmp="$(mktemp -d)" || exit 2; trap 'rm -rf "$tmp"' EXIT
now_ns() { date +%s%N; }
# ms_of CMD... : wall-clock milliseconds, rounded up to at least 1; empty output on command failure
ms_of() { local a b; a=$(now_ns); "$@" >/dev/null 2>&1 || { echo ""; return; }; b=$(now_ns); local d=$(( (b - a) / 1000000 )); [[ "$d" -ge 1 ]] || d=1; echo "$d"; }
emit() { # name value dir absmax
  local name="$1" value="$2" dir="$3" absmax="$4"
  [[ -n "$value" ]] && [[ "$value" =~ ^[0-9]+$ ]] && [[ "$value" -ge 1 ]] || { echo "NO CHECK PERFORMED: measurement failed for $name" >&2; exit 2; }
  printf '%s\t%s\t%s\t%s\n' "$name" "$value" "$dir" "$absmax"
}
want() { local k="$1"; [[ "$kind" == all ]] || [[ "$kind" == "$k" ]]; }
# fixtures
mkdir -p "$tmp/b"
for i in 01 02 03; do printf 'lat\t100\tlower\n' > "$tmp/b/000000$i-r.tsv"; done
awk 'BEGIN { for (i = 0; i < 200; i++) printf "b%d\t%d\tlower\n", i, 100 + i }' > "$tmp/s200.tsv"
awk 'BEGIN { for (i = 0; i < 20000; i++) printf "b%d\t%d\tlower\n", i, 100 + (i % 50) }' > "$tmp/s20k.tsv"
for i in 01 02 03; do cp "$tmp/s20k.tsv" "$tmp/b20k-$i.tsv"; done; mkdir -p "$tmp/b20k"; mv "$tmp/b20k-"*.tsv "$tmp/b20k/"
mkdir -p "$tmp/b200"; for i in 01 02 03; do cp "$tmp/s200.tsv" "$tmp/b200/000000$i-r.tsv"; done
echo hello > "$tmp/golden"
if want B-LAT; then
  emit kit-check-coverage-latency-ms "$(ms_of "$root/kit/check-coverage.sh" --root "$root" --through-sweep 3)" lower 10000
  emit kit-sixsigma-200rows-latency-ms "$(ms_of "$root/benchmarks/sixsigma/sixsigma.sh" --baseline-dir "$tmp/b200" "$tmp/s200.tsv")" lower 10000
  emit kit-regression-latency-ms "$(ms_of "$root/kit/lib/regression.sh" --golden "$tmp/golden" -- echo hello)" lower 5000
fi
if want B-THR; then
  ms=$(ms_of "$root/benchmarks/sixsigma/sixsigma.sh" --baseline-dir "$tmp/b20k" "$tmp/s20k.tsv")
  [[ -n "$ms" ]] || { echo "NO CHECK PERFORMED: 20k-row classification failed" >&2; exit 2; }
  emit kit-sixsigma-rows-per-sec "$(( 20000 * 1000 / ms ))" higher ""
fi
if want B-MEM; then
  # peak RSS of the classifier run: GNU time if present, else python3's getrusage on the child
  tf=""; for c in /usr/bin/time /bin/time; do [[ -x "$c" ]] && tf="$c" && break; done
  if [[ -n "$tf" ]]; then
    "$tf" -f '%M' -o "$tmp/rss" "$root/benchmarks/sixsigma/sixsigma.sh" --baseline-dir "$tmp/b20k" "$tmp/s20k.tsv" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then
    python3 -I -c 'import resource,subprocess,sys
subprocess.run(sys.argv[2:],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
open(sys.argv[1],"w").write(str(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss))' "$tmp/rss" "$root/benchmarks/sixsigma/sixsigma.sh" --baseline-dir "$tmp/b20k" "$tmp/s20k.tsv"
  else echo "NO CHECK PERFORMED: neither GNU time nor python3 available for B-MEM" >&2; exit 2; fi
  emit kit-sixsigma-20k-peak-rss-kb "$(tr -dc '0-9' < "$tmp/rss" 2>/dev/null)" lower 1048576
fi
if want B-STA; then
  emit kit-bench-wrapper-startup-ms "$(ms_of "$root/kit/lib/bench.sh" --kind B-LAT --baseline-dir "$tmp/b" -- bash -c "printf 'lat\t100\tlower\n'")" lower 5000
  emit kit-ptb-source-startup-ms "$(ms_of "$root/kit/lib/ptb.sh")" lower 5000
  # cold versus warm start of one lib: first call in a clean environment, then the best of 5 repeats.
  # Cold is "first call in a fresh process tree" (the page cache is not dropped; that needs root).
  cold="$(ms_of env -i PATH="$PATH" bash "$root/kit/lib/contract.sh" --require hello -- echo hello)"
  warm=""
  for _ in 1 2 3 4 5; do
    w="$(ms_of env -i PATH="$PATH" bash "$root/kit/lib/contract.sh" --require hello -- echo hello)"
    [[ -n "$w" ]] && { [[ -z "$warm" ]] || [[ "$w" -lt "$warm" ]]; } && warm="$w"
  done
  emit kit-cold-start-ms "$cold" lower 5000
  emit kit-warm-start-ms "$warm" lower 5000
fi
if want B-BLD; then
  emit kit-lib-syntax-build-ms "$(ms_of bash -c 'for f in "$0"/kit/lib/*.sh; do bash -n "$f" || exit 1; done' "$root")" lower 10000
fi
