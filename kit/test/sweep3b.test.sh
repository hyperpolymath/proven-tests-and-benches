#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for benchmarks/kit/bench-kit.sh: >= 6 targets, valid TSV, classifies against its own baseline.
root="$(cd "$(dirname "$0")/../.." && pwd)"
. "$root/kit/lib/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
B="$root/benchmarks/kit/bench-kit.sh"
"$B" >"$tmp/all.tsv" 2>/dev/null; ptb_eq bench-kit-all-exit 0 "$?"
ptb_eq bench-kit-six-plus-targets 0 "$([[ "$(wc -l <"$tmp/all.tsv")" -ge 6 ]]; echo $?)"
ptb_eq bench-kit-rows-valid 0 "$(awk -F'\t' 'BEGIN{bad=0} $1=="" || $2 !~ /^[0-9]+$/ || $2 < 1 || ($3 != "lower" && $3 != "higher") {bad=1} END{exit bad}' "$tmp/all.tsv"; echo $?)"
ptb_eq bench-kit-unique-names 0 "$([[ "$(cut -f1 "$tmp/all.tsv" | sort -u | wc -l)" -eq "$(wc -l <"$tmp/all.tsv")" ]]; echo $?)"
for k in B-LAT B-THR B-MEM B-STA B-BLD; do ptb_eq "bench-kit-$k" 0 "$(code "$B" "$k")"; done
ptb_eq bench-kit-bad-kind 2 "$(code "$B" B-XXX)"
ptb_eq bench-kit-eng-unsupported 2 "$(code "$B" B-ENG)"
ptb_eq bench-kit-cold-warm-targets 2 "$(grep -c "^kit-\(cold\|warm\)-start-ms" "$tmp/all.tsv")"
# end to end: its own output as baseline classifies Ordinary (exit 0) through bench.sh
mkdir "$tmp/base"; for i in 01 02 03; do cp "$tmp/all.tsv" "$tmp/base/000000$i-r.tsv"; done
ptb_eq bench-kit-vs-self 0 "$(code "$root/kit/lib/bench.sh" --kind B-LAT --baseline-dir "$tmp/base" -- cat "$tmp/all.tsv")"
# negative control: a 3x regression on every row must not pass
awk -F'\t' 'BEGIN{OFS="\t"} {$2 = ($3=="lower") ? $2*3 : int($2/3)+0; if ($2<1) $2=1; print}' "$tmp/all.tsv" > "$tmp/worse.tsv"
ptb_eq bench-kit-regression-caught 1 "$(code "$root/kit/lib/bench.sh" --kind B-LAT --baseline-dir "$tmp/base" -- cat "$tmp/worse.tsv")"
ptb_done
