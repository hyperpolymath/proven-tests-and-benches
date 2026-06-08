#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
# Copyright (c) 2026 Joshua Jewell (hyperpolymath)

set -euo pipefail

echo "Running Proven-Tests Benchmark Suite..."
echo ""

# Run the benchmark using idris2
idris2 --exec benchMain -p proven-tests --benchmark

echo ""
echo "Benchmark suite complete!"
