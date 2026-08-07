#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Build and run everything in the repository against Idris2. Assumes idris2 is
# installed in $HOME/.idris2 (see install-idris2.sh). Each test executable
# exits non-zero if any suite fails, so this script gates CI.

set -euxo pipefail

export PATH="$HOME/.idris2/bin:$PATH"
# Derive the support-library path from the installed version rather than
# hardcoding one, so toolchain bumps cannot silently break the runner.
for libdir in "$HOME"/.idris2/idris2-*/lib; do
  export LD_LIBRARY_PATH="$libdir:${LD_LIBRARY_PATH:-}"
done

idris2 --version

echo "--- building library ---"
idris2 --build proven-tests.ipkg

echo "--- installing library (so dependents can build against it) ---"
idris2 --install proven-tests.ipkg

echo "--- building type-safe test suite package ---"
idris2 --build proven-tests-suite.ipkg

# NOTE (2026-08-07): proven-spec-suite was built and run by NOTHING — not this
# script, not a just recipe, not a workflow step. It carries 75 tests across
# ProvenLawsTests, AffineScriptTests, HigherOrderTests and SetTheoryTests,
# including the 12 Actually-Proven theorems that PROOFS.adoc headlines as this
# repository's top-tier evidence. Those theorems were the strongest claim in the
# repo and nothing had ever confirmed they still compile. They gate now.
echo "--- building spec suite package (Proven laws, AffineScript, HigherOrder, SetTheory) ---"
idris2 --build proven-spec-suite.ipkg

echo "--- building benchmark ---"
idris2 --build benchmarks/benchmark.ipkg

echo "--- running framework self-test suite + emitting JSON run report ---"
mkdir -p build/report
./build/exec/proven-tests --report build/report/proven-tests-report.json

echo "--- running type-safe test suite (exits non-zero on failure) ---"
./build/exec/proven-tests-suite

echo "--- running spec suite (exits non-zero on failure) ---"
./build/exec/proven-spec-suite

echo "--- running benchmark ---"
./benchmarks/build/exec/proven-bench

# The proven subject report grades a real external subject. It needs only
# proven's ledger files (no code dependency), so it runs whenever a proven
# checkout is reachable; otherwise it is skipped, not failed.
#
# NOTE (2026-08-03): PROVEN_ROOT defaulted to the single hardcoded path
# /home/user/proven, which exists on no machine in this estate — so this step
# was skipped on every run that has ever happened, while the actual checkout
# sat at ../proven relative to this repository. That matters more than a
# missing report: READINESS.adoc rests its CRG grade on this step's output,
# so the headline evidence for the grade had never been produced. The default
# now searches the places a sibling checkout actually lives; an explicit
# PROVEN_ROOT still wins.
if [ -z "${PROVEN_ROOT:-}" ]; then
  for candidate in \
    "$(dirname "$PWD")/proven" \
    "$PWD/../proven" \
    "$HOME/developer/hyper-repos/proven" \
    "/home/user/proven"
  do
    if [ -f "$candidate/MODULE-STATUS.txt" ]; then
      PROVEN_ROOT="$candidate"
      break
    fi
  done
fi
PROVEN_ROOT="${PROVEN_ROOT:-/nonexistent}"

if [ -f "$PROVEN_ROOT/MODULE-STATUS.txt" ]; then
  echo "--- building proven subject report ---"
  idris2 --build integrations/proven/proven-subject.ipkg
  echo "--- running proven subject report (PROVEN_ROOT=$PROVEN_ROOT) ---"
  ( cd integrations/proven && PROVEN_ROOT="$PROVEN_ROOT" ./build/exec/proven-subject-report )
else
  # Deliberately loud. A skip here is NOT a pass, and the CRG evidence in
  # READINESS.adoc depends on this step having run.
  echo "--- SKIPPED: proven subject report — no proven checkout found ---" >&2
  echo "    Searched: ../proven, \$HOME/developer/hyper-repos/proven" >&2
  echo "    Set PROVEN_ROOT to grade the subject. A skip is not a pass." >&2
fi
