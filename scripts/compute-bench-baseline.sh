#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Compute the benchmark baseline from proven-bench JSON v1 run files.
#
# Usage: scripts/compute-bench-baseline.sh <run.json>... > benchmarks/baseline.json
#
# Taxonomy (standards TESTING-TAXONOMY.adoc, Part IV "Baseline Management"):
# "Baselines are established from the mean of the last 10 CI runs on main."
# So this script takes AT LEAST 10 run files and refuses fewer: below ten the
# gate is mathematically inert, and it says so (exit 2, "BASELINE
# BOOTSTRAPPING") rather than writing a baseline that looks complete.
# Choosing WHICH runs are "the last 10 on main" is the caller's job, because
# only the caller knows where the artifacts came from (see the regeneration
# recipe in benchmarks/README.adoc).
#
# Provenance: when a file's parent directory is named by digits only (the
# layout `gh run download <run-id> -n proven-bench-<run-id> -D <run-id>`
# produces), that name is recorded as the source's run_id. The output is
# deterministic — no timestamps — so regenerating from the same artifacts
# reproduces the committed file byte for byte.
#
# Checksums are NOT vetted here (bench-stats.jq `checksum_errors` explains
# why: artifacts from before #85 carry an XOR-parity checksum that was False on
# every run). The gate vets the current run's checksum instead.
#
# Exit codes: 0 baseline written to stdout; 2 no baseline could be computed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" || { echo "FAIL: cannot locate script directory" >&2; exit 2; }
MIN_RUNS=10

# die: print a reason to stderr and exit 2 (no baseline was computed).
die() {
  echo "compute-bench-baseline: $*" >&2
  echo "compute-bench-baseline: NO BASELINE WRITTEN." >&2
  exit 2
}

# run_id_of: print the digits-only parent directory name of a file, or
# nothing when the parent is not named by a run id.
run_id_of() {
  local parent
  parent="$(basename "$(dirname "$1")")"
  if [[ "$parent" =~ ^[0-9]+$ ]]; then
    printf '%s' "$parent"
  fi
}

# validate_run: refuse a run file that is missing, unparseable, or not a
# well-formed proven-bench v1 document, naming every shape error found.
validate_run() {
  local f="$1" errs
  [ -f "$f" ] || die "run file '$f' does not exist"
  if ! errs="$(jq -L "$SCRIPT_DIR" -r 'include "bench-stats"; bench_errors[]' "$f")"; then
    die "run file '$f' is not parseable JSON"
  fi
  if [ -n "$errs" ]; then
    printf '%s\n' "$errs" | sed "s|^|  $f: |" >&2
    die "run file '$f' is not a well-formed proven-bench v1 document"
  fi
}

[ "$#" -ge 1 ] || die "usage: $0 <run.json>... (at least $MIN_RUNS)"
if [ "$#" -lt "$MIN_RUNS" ]; then
  die "BASELINE BOOTSTRAPPING: $#/$MIN_RUNS runs - the gate would be INERT; supply at least $MIN_RUNS"
fi

ids_json='[]'
for f in "$@"; do
  validate_run "$f"
  ids_json="$(jq -c --arg id "$(run_id_of "$f")" '. + [ if $id == "" then null else $id end ]' <<<"$ids_json")" \
    || die "could not record provenance for '$f'"
done

# Every run must measure the SAME frozen workload set with the SAME iteration
# counts; mixing workload definitions would average different experiments.
if ! jq -L "$SCRIPT_DIR" -s -e 'include "bench-stats";
      (map(iterations_map) | unique | length) == 1' "$@" >/dev/null; then
  die "the run files disagree on the workload set or iteration counts - they measure different experiments"
fi

jq -L "$SCRIPT_DIR" -s --argjson ids "$ids_json" '
  include "bench-stats";
  . as $runs
  | ($runs[0] | iterations_map) as $iters
  | ($runs | map(loo_ratios)) as $loo
  | ($runs | map(medians)) as $med
  | {
      schema_version: 1,
      kind: "proven-bench-baseline",
      bench_schema_version: 1,
      statistic: "leave-one-out ratio: a workload median divided by the geometric mean of the other workloads medians in the same run",
      method: "arithmetic mean over the source runs (taxonomy: mean of the last 10 CI runs on main)",
      note: "Manual tolerance override (taxonomy Part IV permits one with a stated reason): the checker fails at 2.0x the baseline ratio or 2.5x the baseline absolute median, not the taxonomy 1.5x, because 1.5x would have failed green runs on shared GitHub runners (max observed ratio 1.53x, absolute 1.65x). Measured numbers are in benchmarks/README.adoc and scripts/check-bench-regression.sh.",
      window: ($runs | length),
      sources: [ range(0; $runs | length) as $i
                 | { run_id: $ids[$i], commit: $runs[$i].commit } ],
      workloads: ( $iters | keys | map({
        key: .,
        value: {
          iterations: $iters[.],
          mean_median_ns: ([ $med[][.] ] | add / length),
          mean_loo_ratio: ([ $loo[][.] ] | add / length)
        } }) | from_entries )
    }
' "$@" || die "jq failed while computing the baseline"
