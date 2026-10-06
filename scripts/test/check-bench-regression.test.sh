#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Self-test for the benchmark regression gate: proves the gate CAN fail, and
# fails for the right reason, before CI trusts its green.
#
# Every control plants a known answer and asserts BOTH the exit code AND the
# reason in the output, so a gate that failed on everything would still be
# caught (by the identical-run control) and a gate that failed for the wrong
# reason would be caught by the reason match.
#
# Exit codes: 0 every control behaved as planted; 1 at least one did not.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)" || { echo "FAIL: cannot reach repository root" >&2; exit 1; }
CHECK="$ROOT/scripts/check-bench-regression.sh"
COMPUTE="$ROOT/scripts/compute-bench-baseline.sh"

WORK="$(mktemp -d)" || { echo "FAIL: mktemp" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0

# make_run: write a well-formed proven-bench v1 run to $1. Remaining args are
# name=median_ns pairs; every workload gets 100 iterations and checksum true.
make_run() {
  local out="$1"; shift
  printf '%s\n' "$@" | jq -R -s '
    split("\n") | map(select(length > 0) | split("=")
      | { name: .[0], iterations: 100, samples_ns: [ (.[1] | tonumber) ],
          median_ns: (.[1] | tonumber), checksum: true })
    | { schema_version: 1, suite: "proven-bench", reps: 1,
        commit: "selftest", runner: "selftest", results: . }' > "$out"
}

# expect: run a command, then assert its exit code equals $2 and its combined
# output matches the extended regex $3. $1 names the control.
expect() {
  local label="$1" want_rc="$2" want_re="$3" out rc
  shift 3
  if out="$("$@" 2>&1)"; then rc=0; else rc=$?; fi
  if [ "$rc" -eq "$want_rc" ] && grep -qE -- "$want_re" <<<"$out"; then
    echo "  PASS  $label (exit $rc)"
    passed=$((passed + 1))
  else
    echo "  FAIL  $label: wanted exit $want_rc matching /$want_re/, got exit $rc:"
    sed 's/^/        | /' <<<"$out"
    failed=$((failed + 1))
  fi
}

# refute: assert the combined output of a command does NOT match regex $2.
# $1 names the control. The command's exit code is not examined here.
refute() {
  local label="$1" bad_re="$2" out
  shift 2
  out="$("$@" 2>&1)"
  if grep -qE -- "$bad_re" <<<"$out"; then
    echo "  FAIL  $label: output unexpectedly matched /$bad_re/:"
    sed 's/^/        | /' <<<"$out"
    failed=$((failed + 1))
  else
    echo "  PASS  $label"
    passed=$((passed + 1))
  fi
}

echo "check-bench-regression self-test"

# --- Fixtures -------------------------------------------------------------
make_run "$WORK/base.json"     alpha=1000000 beta=2000000 gamma=3000000 delta=4000000
make_run "$WORK/slow-beta.json" alpha=1000000 beta=6000000 gamma=3000000 delta=4000000
make_run "$WORK/uniform3x.json" alpha=3000000 beta=6000000 gamma=9000000 delta=12000000
# beta 3x slower on a runner 0.6x as fast as the baseline: absolute 1.8x, under
# the absolute backstop, so ONLY the ratio statistic can catch it.
make_run "$WORK/slow-beta-fast-runner.json" alpha=600000 beta=3600000 gamma=1800000 delta=2400000
make_run "$WORK/noisy.json"    alpha=1400000 beta=2000000 gamma=3000000 delta=4000000
make_run "$WORK/no-delta.json" alpha=1000000 beta=2000000 gamma=3000000
make_run "$WORK/extra.json"    alpha=1000000 beta=2000000 gamma=3000000 delta=4000000 eps=5000000
make_run "$WORK/zero.json"     alpha=0       beta=2000000 gamma=3000000 delta=4000000
jq '.results[1].checksum = false' "$WORK/base.json" > "$WORK/badsum.json"
jq '.results[0].iterations = 200' "$WORK/base.json" > "$WORK/reiter.json"
printf '{ "schema_version": 1, "results": [ \n' > "$WORK/malformed.json"

for i in $(seq 1 10); do
  mkdir -p "$WORK/runs/$((1000 + i))"
  cp "$WORK/base.json" "$WORK/runs/$((1000 + i))/proven-bench.json"
done
if ! bash "$COMPUTE" "$WORK"/runs/*/proven-bench.json > "$WORK/baseline.json"; then
  echo "  FAIL  could not compute the self-test baseline from 10 identical runs"
  exit 1
fi

# --- Controls ---------------------------------------------------------------
expect "identical run passes"                0 'OK - no workload regressed' \
  bash "$CHECK" "$WORK/base.json" "$WORK/baseline.json"
expect "noise inside tolerance passes"       0 'OK - no workload regressed' \
  bash "$CHECK" "$WORK/noisy.json" "$WORK/baseline.json"
expect "one workload 3x slower fails, named" 1 'Unacceptable regression in: beta$' \
  bash "$CHECK" "$WORK/slow-beta.json" "$WORK/baseline.json"
expect "3x slower on a fast runner fails on ratio alone" 1 'Unacceptable regression in: beta$' \
  bash "$CHECK" "$WORK/slow-beta-fast-runner.json" "$WORK/baseline.json"
refute "3x slowdown blames only that workload" '(alpha|gamma|delta) .*UNACCEPTABLE' \
  bash "$CHECK" "$WORK/slow-beta.json" "$WORK/baseline.json"
expect "uniform 3x slowdown fails (absolute backstop)" 1 'Unacceptable regression in: alpha beta delta gamma$' \
  bash "$CHECK" "$WORK/uniform3x.json" "$WORK/baseline.json"
expect "workload missing from current run fails" 2 'MISSING from current run: delta' \
  bash "$CHECK" "$WORK/no-delta.json" "$WORK/baseline.json"
expect "workload missing from baseline fails"    2 'MISSING from baseline: eps' \
  bash "$CHECK" "$WORK/extra.json" "$WORK/baseline.json"
expect "changed iteration count fails"           2 'iterations changed for alpha' \
  bash "$CHECK" "$WORK/reiter.json" "$WORK/baseline.json"
expect "missing baseline fails"                  2 "baseline '.*' does not exist" \
  bash "$CHECK" "$WORK/base.json" "$WORK/nonexistent-baseline.json"
expect "malformed baseline JSON fails"           2 "baseline '.*' is not parseable JSON" \
  bash "$CHECK" "$WORK/base.json" "$WORK/malformed.json"
expect "malformed current JSON fails"            2 "current run '.*' is not parseable JSON" \
  bash "$CHECK" "$WORK/malformed.json" "$WORK/baseline.json"
expect "a run given as the baseline fails"       2 'kind is null' \
  bash "$CHECK" "$WORK/base.json" "$WORK/base.json"
expect "non-positive median fails"               2 'alpha: median_ns 0 is not a positive number' \
  bash "$CHECK" "$WORK/zero.json" "$WORK/baseline.json"
expect "false checksum in current run fails"     2 'beta: checksum is false' \
  bash "$CHECK" "$WORK/badsum.json" "$WORK/baseline.json"
expect "wrong argument count fails"              2 'usage:' \
  bash "$CHECK" "$WORK/base.json"
expect "baseline from fewer than 10 runs refused" 2 'BASELINE BOOTSTRAPPING: 3/10' \
  bash "$COMPUTE" "$WORK/runs/1001/proven-bench.json" "$WORK/runs/1002/proven-bench.json" "$WORK/runs/1003/proven-bench.json"
expect "baseline records run ids from directory names" 0 '"run_id": "1001"' \
  cat "$WORK/baseline.json"

echo "check-bench-regression self-test: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
