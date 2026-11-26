#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Self-test for sixsigma.sh: every class, both directions, both boundaries,
# the absolute backstop, the mean-of-last-10 window, and every no-check path.
set -u
sx="$(cd "$(dirname "$0")" && pwd)/sixsigma.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
want() { local name="$1" code="$2" pat="$3"; shift 3
  out=$("$@" 2>&1); got=$?
  if [ "$got" -eq "$code" ] && printf '%s' "$out" | grep -q -- "$pat"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $name: want exit $code /$pat/ got $got: $out"; fi; }
mk() { printf '%s\t%s\t%s\n' "$2" "$3" "$4" > "$1"; }
b="$tmp/base"; mkdir -p "$b"
for i in 01 02 03 04 05 06 07 08 09 10; do mk "$b/000000$i-run.tsv" lat 100 lower; printf 'thr\t1000\thigher\n' >> "$b/000000$i-run.tsv"; done
run() { printf 'lat\t%s\tlower\nthr\t%s\thigher\n' "$1" "$2" > "$tmp/r.tsv"; "$sx" --baseline-dir "$b" "$tmp/r.tsv"; }
want ordinary-equal            0 "overall: Ordinary"      run 100 1000
want ordinary-just-under-20    0 "overall: Ordinary"      run 119 1000
want acceptable-at-20          3 "overall: Acceptable"    run 120 1000
want acceptable-at-50          3 "overall: Acceptable"    run 150 1000
want unacceptable-over-50      1 "overall: Unacceptable"  run 151 1000
want extraordinary-faster      0 "Extraordinary"          run 70 1000
want ordinary-at-20-improve    0 "overall: Ordinary"      run 80 1000
want higher-is-better-regress  1 "overall: Unacceptable"  run 100 400
want higher-is-better-improve  0 "Extraordinary"          run 100 1500
# absolute backstop: within 20% of baseline but over an absolute ceiling
printf 'lat\t110\tlower\t105\n' > "$tmp/abs.tsv"
want absolute-breach           1 "absolute threshold breached" "$sx" --baseline-dir "$b" "$tmp/abs.tsv"
# window: 12 files, the oldest two (value 1000) must be ignored -> baseline is 100
b2="$tmp/base2"; mkdir -p "$b2"
for i in 01 02; do mk "$b2/000000$i-old.tsv" lat 1000 lower; done
for i in 03 04 05 06 07 08 09 10 11 12; do mk "$b2/000000$i-new.tsv" lat 100 lower; done
printf 'lat\t100\tlower\n' > "$tmp/w.tsv"
want window-uses-last-10       0 "base=100 "  "$sx" --baseline-dir "$b2" "$tmp/w.tsv"
# no-check paths are exit 2, never 0
want missing-baseline-dir-is-2     2 "baseline dir missing"  "$sx" --baseline-dir "$tmp/none" "$tmp/w.tsv"
mkdir -p "$tmp/empty"; want empty-dir-is-2 2 "no baseline" "$sx" --baseline-dir "$tmp/empty" "$tmp/w.tsv"
want missing-results-is-2      2 "results file" "$sx" --baseline-dir "$b" "$tmp/gone.tsv"
printf 'lat\tfast\tlower\n' > "$tmp/bad.tsv"
want malformed-value-is-2      2 "malformed"  "$sx" --baseline-dir "$b" "$tmp/bad.tsv"
printf 'lat\t0\tlower\n' > "$tmp/zero.tsv"
want zero-value-is-2           2 "malformed"  "$sx" --baseline-dir "$b" "$tmp/zero.tsv"
printf 'novel\t5\tlower\n' > "$tmp/nb.tsv"
want bench-without-baseline-2  2 "no baseline rows" "$sx" --baseline-dir "$b" "$tmp/nb.tsv"
want short-window-strict-is-2  2 "require-full-window" "$sx" --require-full-window --window 20 --baseline-dir "$b" "$tmp/w.tsv"
want json-output               0 '"class":"Ordinary"' "$sx" --json --baseline-dir "$b" "$tmp/w.tsv"
echo "sixsigma self-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && [ "$pass" -ge 19 ]
