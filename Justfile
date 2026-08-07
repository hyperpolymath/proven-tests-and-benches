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

# Provision the Idris2 toolchain (referenced by .devcontainer postCreateCommand)
deps:
    bash scripts/install-idris2.sh

# Verify every artefact pins the same Idris2 version (fails on drift)
check-pins:
    bash scripts/check-toolchain-pins.sh

# Build the framework library
build:
    idris2 --build proven-tests.ipkg

# Install the framework library (dependents build against it)
install: build
    idris2 --install proven-tests.ipkg

# Build and run every test package: the framework self-test, the type-safe
# category suite, and the spec suite (Proven laws, AffineScript, HigherOrder,
# SetTheory). The spec suite was absent from this recipe — and from the CI gate
# — until 2026-08-07, so its 75 tests and 12 Actually-Proven theorems were
# exercised by nothing automated.
test: install
    #!/usr/bin/env bash
    set -euo pipefail
    for libdir in "$HOME"/.idris2/idris2-*/lib; do
        export LD_LIBRARY_PATH="$libdir:${LD_LIBRARY_PATH:-}"
    done
    idris2 --build proven-tests-suite.ipkg
    idris2 --build proven-spec-suite.ipkg
    ./build/exec/proven-tests
    ./build/exec/proven-tests-suite
    ./build/exec/proven-spec-suite

# Run only the spec suite package (Proven laws, AffineScript, HigherOrder, SetTheory)
test-spec: install
    #!/usr/bin/env bash
    set -euo pipefail
    for libdir in "$HOME"/.idris2/idris2-*/lib; do
        export LD_LIBRARY_PATH="$libdir:${LD_LIBRARY_PATH:-}"
    done
    idris2 --build proven-spec-suite.ipkg
    ./build/exec/proven-spec-suite

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

# NOTE: this recipe used to end in `|| echo "none found"`, which made it report
# but never fail — grep exits 1 when it finds nothing, so the `||` branch fired
# on the CLEAN case, and the dirty case exited 0 as well. It gated nothing.
# Inverted: a hit is now a failure, absence is the success path.
#
# NOTE (2026-08-07): the grep used to live inline here AND inline in
# .github/workflows/ci.yml, and both copies covered only four of the six
# patterns AGENTIC.a2ml bans — `idris_crash` and hole syntax (?name) were
# prohibited by the manifest and matched by neither. One copy now, in
# scripts/check-escape-hatches.sh, called by both.
#
# Fail if any proof escape hatch appears in Idris2 sources (the honesty lint)
lint:
    bash scripts/check-escape-hatches.sh

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

# NOTE: this recipe used to end in `|| true`, so it exited 0 whether trufflehog
# was missing OR had found live secrets. Both failure modes read as green.
# A missing scanner is now distinguishable (exit 2) from a clean scan (exit 0)
# and from findings (exit 1).
#
# Verified-secret scan. Absent tool = explicit skip (exit 2), NOT a pass.
secret-scan-trufflehog:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v trufflehog >/dev/null 2>&1; then
        echo "SKIP: trufflehog is not installed — NO SCAN WAS PERFORMED."
        echo "      Install it, or run the pre-commit hook, before trusting this repo as clean."
        exit 2
    fi
    if ! trufflehog filesystem . --only-verified --fail; then
        echo "FAIL: trufflehog reported verified secrets."
        exit 1
    fi
    echo "OK: no verified secrets found."
