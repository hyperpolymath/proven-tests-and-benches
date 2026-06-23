#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Build and run everything in the repository against Idris2. Assumes idris2 is
# installed in $HOME/.idris2 (see install-idris2.sh). The test executable exits
# non-zero if any suite fails, so this script gates CI.

set -euxo pipefail

export PATH="$HOME/.idris2/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/.idris2/idris2-0.7.0/lib:${LD_LIBRARY_PATH:-}"

idris2 --version

echo "--- building library ---"
idris2 --build proven-tests.ipkg

echo "--- installing library (so the benchmark can depend on it) ---"
idris2 --install proven-tests.ipkg

echo "--- building benchmark ---"
idris2 --build benchmarks/benchmark.ipkg

echo "--- running test suite (exits non-zero on failure) ---"
./build/exec/proven-tests

echo "--- running benchmark ---"
./benchmarks/build/exec/proven-bench
