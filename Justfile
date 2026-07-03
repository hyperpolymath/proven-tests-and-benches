# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#

# Proven-Tests build and test automation.
# Every recipe reflects a real, working command; scripts/ci-build.sh remains
# the single source of truth for the full CI gate.

export PATH := env_var("HOME") + "/.idris2/bin:" + env_var("PATH")

# Default: build and run everything
default: build test

# Build the framework library
build:
    idris2 --build proven-tests.ipkg

# Install the framework library (dependents build against it)
install: build
    idris2 --install proven-tests.ipkg

# Build and run the framework self-test suite and the type-safe test suite
test: install
    #!/usr/bin/env bash
    set -euo pipefail
    for libdir in "$HOME"/.idris2/idris2-*/lib; do
        export LD_LIBRARY_PATH="$libdir:${LD_LIBRARY_PATH:-}"
    done
    idris2 --build proven-tests-suite.ipkg
    ./build/exec/proven-tests
    ./build/exec/proven-tests-suite

# Run only the type-safe category suite package
test-typesafe: install
    #!/usr/bin/env bash
    set -euo pipefail
    for libdir in "$HOME"/.idris2/idris2-*/lib; do
        export LD_LIBRARY_PATH="$libdir:${LD_LIBRARY_PATH:-}"
    done
    idris2 --build proven-tests-suite.ipkg
    ./build/exec/proven-tests-suite

# Build and run the benchmark harness
bench: install
    #!/usr/bin/env bash
    set -euo pipefail
    for libdir in "$HOME"/.idris2/idris2-*/lib; do
        export LD_LIBRARY_PATH="$libdir:${LD_LIBRARY_PATH:-}"
    done
    idris2 --build benchmarks/benchmark.ipkg
    ./benchmarks/build/exec/proven-bench

# Run the full CI gate (what the hosted pipelines run)
ci:
    bash scripts/ci-build.sh

# Remove build artifacts
clean:
    rm -rf build benchmarks/build

# Report proof escape hatches (the honesty lint)
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Scanning for proof escape hatches..."
    grep -rn "believe_me\|assert_total\|%partial\|unsafePerformIO" src/ tests/ benchmarks/ --include="*.idr" || echo "none found"

# Print the shields.io badge URL for the current CRG grade
crg-badge:
    #!/usr/bin/env bash
    set -euo pipefail
    GRADE=$(grep "Current Grade:" READINESS.adoc | head -1 | sed 's/.*Current Grade:[^A-Z]*\([A-Z]\).*/\1/')
    [ -z "$GRADE" ] && GRADE="X"
    case "$GRADE" in
        A) COLOR="brightgreen" ;;
        B) COLOR="green" ;;
        C) COLOR="yellowgreen" ;;
        D) COLOR="orange" ;;
        E|F) COLOR="red" ;;
        *) COLOR="lightgrey" ;;
    esac
    echo "https://img.shields.io/badge/CRG-${GRADE}-${COLOR}?style=flat-square"

# Print the current Component Readiness Grade
crg-grade:
    #!/usr/bin/env bash
    set -euo pipefail
    GRADE=$(grep "Current Grade:" READINESS.adoc | head -1 | sed 's/.*Current Grade:[^A-Z]*\([A-Z]\).*/\1/')
    if [ -z "$GRADE" ]; then
        echo "ERROR: No Current Grade found in READINESS.adoc"
        exit 1
    fi
    echo "Current CRG Grade: $GRADE"

# Best-effort verified-secret scan (no-op if trufflehog absent)
secret-scan-trufflehog:
    @command -v trufflehog >/dev/null && trufflehog filesystem . --only-verified || true
