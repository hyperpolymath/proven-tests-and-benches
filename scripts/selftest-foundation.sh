#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# selftest-foundation.sh — runs every self-test of the foundation kit. One
# entry point for CI (F2's umbrella calls this). Exit 0 only if every suite ran
# and passed; a suite that is missing is a failure (DOG-01), not a skip.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"; cd "$root" || exit 2
fail=0
run() { echo "== $1"; shift; "$@" || { echo "FAILED: $*" >&2; fail=1; }; }
for t in kit/test/check-coverage.test.sh kit/test/lib.test.sh kit/test/sweep2.test.sh kit/test/sweep2b.test.sh kit/test/sweep2c.test.sh kit/test/sweep3.test.sh kit/test/sweep3b.test.sh benchmarks/sixsigma/test-sixsigma.sh \
         scripts/test/agda-prove.test.sh kit/templates/bash/sweep1.test.sh; do
  [ -x "$t" ] || { echo "MISSING self-test: $t" >&2; fail=1; continue; }
  run "$t" "$t"
done
run "kit mutation self-check (>= 80% per lib)" scripts/mutation-selfcheck.sh
run "coverage matrix is current and every path exists" taxonomy-coverage/gen-matrix.sh --check
if command -v cargo >/dev/null; then
  run "rust template" cargo test --offline --quiet --manifest-path kit/templates/rust/Cargo.toml
else echo "NO CHECK PERFORMED: cargo absent, rust template not run" >&2; fail=1; fi
run "agda template proves" scripts/agda-prove.sh kit/templates/agda
[ "$fail" -eq 0 ] && echo "FOUNDATION SELF-TEST: ALL PASS" || echo "FOUNDATION SELF-TEST: FAILED" >&2
exit "$fail"
