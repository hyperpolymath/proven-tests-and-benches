#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
# Copyright (c) 2026 Joshua Jewell (hyperpolymath)

set -euo pipefail

echo "Running Proven-Tests Benchmark Suite..."
echo ""

# The benchmark depends on the proven-tests package, so install it first.
idris2 --install proven-tests.ipkg
idris2 --build benchmarks/benchmark.ipkg

./benchmarks/build/exec/proven-bench

echo ""
echo "Benchmark suite complete!"
