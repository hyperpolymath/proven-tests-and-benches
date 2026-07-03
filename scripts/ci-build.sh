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

echo "--- building benchmark ---"
idris2 --build benchmarks/benchmark.ipkg

echo "--- running framework self-test suite + emitting JSON run report ---"
mkdir -p build/report
./build/exec/proven-tests --report build/report/proven-tests-report.json

echo "--- running type-safe test suite (exits non-zero on failure) ---"
./build/exec/proven-tests-suite

echo "--- running benchmark ---"
./benchmarks/build/exec/proven-bench

# The proven subject report grades a real external subject. It needs only
# proven's ledger files (no code dependency), so it runs whenever a proven
# checkout is reachable; otherwise it is skipped, not failed.
PROVEN_ROOT="${PROVEN_ROOT:-/home/user/proven}"
if [ -f "$PROVEN_ROOT/MODULE-STATUS.txt" ]; then
  echo "--- building proven subject report ---"
  idris2 --build integrations/proven/proven-subject.ipkg
  echo "--- running proven subject report (PROVEN_ROOT=$PROVEN_ROOT) ---"
  ( cd integrations/proven && PROVEN_ROOT="$PROVEN_ROOT" ./build/exec/proven-subject-report )
else
  echo "--- skipping proven subject report (no proven checkout at $PROVEN_ROOT) ---"
fi
