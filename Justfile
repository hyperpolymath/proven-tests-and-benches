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

# Rewrite the README badge from READINESS.adoc, and FAIL if it was out of date.
#
# `crg-badge` only prints a URL, so calling the README badge "generated" was
# aspirational: nothing wrote it, and it sat hand-frozen at D for five weeks
# while READINESS.adoc and STATE.a2ml both said C. This recipe closes that —
# it is idempotent, and in --check mode it is a gate that can fail.
#
#   just crg-badge-sync          rewrite README.adoc if needed
#   just crg-badge-sync --check  exit 1 if README disagrees with READINESS.adoc
crg-badge-sync *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    WANT=$(just crg-badge)
    HAVE=$(grep -oE 'https://img\.shields\.io/badge/CRG-[^[]*' README.adoc | head -1)
    if [ "$WANT" = "$HAVE" ]; then
        echo "OK: README badge agrees with READINESS.adoc ($WANT)"
        exit 0
    fi
    if [ "{{ ARGS }}" = "--check" ]; then
        echo "FAIL: README badge disagrees with READINESS.adoc."
        echo "  README.adoc     : $HAVE"
        echo "  READINESS.adoc  : $WANT"
        echo "  Fix with: just crg-badge-sync"
        exit 1
    fi
    python3 - "$WANT" <<'PY'
    import re, sys, pathlib
    want = sys.argv[1]
    p = pathlib.Path("README.adoc"); s = p.read_text()
    s2 = re.sub(r'https://img\.shields\.io/badge/CRG-[^\[]*', want, s, count=1)
    p.write_text(s2)
    PY
    echo "Rewrote README badge -> $WANT"

# Generate the root READINESS.md the estate CRG parser convention expects
# (`**Current Grade:** X` at repo root, parsed by rsr-template-repo tooling).
# GENERATED from READINESS.adoc — the single source of truth — and gated by
# scripts/check-doc-facts.sh so the pair can never drift.
crg-readiness-md:
    #!/usr/bin/env bash
    set -euo pipefail
    GRADE=$(grep "Current Grade:" READINESS.adoc | head -1 | sed 's/.*Current Grade:[^A-Z]*\([A-Z]\).*/\1/')
    [ -n "$GRADE" ] || { echo "ERROR: no Current Grade in READINESS.adoc"; exit 2; }
    cat > READINESS.md <<MD
    <!--
    SPDX-License-Identifier: CC-BY-SA-4.0
    SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

    GENERATED by 'just crg-readiness-md' from READINESS.adoc — do not hand-edit.
    READINESS.adoc is the single source of truth for the grade and its evidence;
    this file exists because the estate CRG convention parses a root READINESS.md
    for the machine-greppable grade line below. Agreement is gated in CI by
    scripts/check-doc-facts.sh.
    -->
    # Readiness

    **Current Grade:** $GRADE

    The grade, its evidence, promotion blockers, and evidence sources live in
    [READINESS.adoc](READINESS.adoc).
    MD
    echo "Generated READINESS.md (grade $GRADE)"

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
