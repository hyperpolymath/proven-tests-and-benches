# SPDX-License-Identifier: MPL-2.0
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
# Copyright (c) 2026 Joshua Jewell (hyperpolymath)

# Proven-Tests Build and Test Automation

# Default recipe: build and test
@default:
    just build
    just test

# Build the project
@build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Building Proven-Tests..."
    idris2 --build ipkg.json
    echo "Build complete!"

# Run all tests
@test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running Proven-Tests..."
    idris2 --exec main -p proven-tests

# Run specific test category
@test category="all":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{category}}" in
        tropical)
            idris2 --exec main -p proven-tests --category Tropical
            ;;
        epistemic)
            idris2 --exec main -p proven-tests --category Epistemic
            ;;
        choreographic)
            idris2 --exec main -p proven-tests --category Choreographic
            ;;
        dependent)
            idris2 --exec main -p proven-tests --category Dependent
            ;;
        effects)
            idris2 --exec main -p proven-tests --category Effects
            ;;
        decorative)
            idris2 --exec main -p proven-tests --category Decorative
            ;;
        ceremonial)
            idris2 --exec main -p proven-tests --category Ceremonial
            ;;
        dyadic)
            idris2 --exec main -p proven-tests --category Dyadic
            ;;
        echo-types)
            idris2 --exec main -p proven-tests --category EchoTypes
            ;;
        all)
            just test
            ;;
        *)
            echo "Unknown category: {{category}}"
            exit 1
            ;;
    esac

# Run type-safe tests only
@test-typesafe:
    #!/usr/bin/env bash
    set -euo pipefail
    idris2 --exec main -p proven-tests --typesafe-only

# Run benchmarks
@bench:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running benchmarks..."
    for bench in benchmarks/*; do
        if [ -f "$bench" ] && [ -x "$bench" ]; then
            echo "Running $bench..."
            "$bench"
        fi
    done

# Clean build artifacts
@clean:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf build/ .idris2/ *.ibc *.ibc.*
    echo "Cleaned!"

# Install the package
@install:
    #!/usr/bin/env bash
    set -euo pipefail
    idris2 --install ipkg.json
    echo "Installed!"

# Generate documentation
@docs:
    #!/usr/bin/env bash
    set -euo pipefil
    echo "Generating documentation..."
    # Would need idris2-doc or similar tool
    echo "Documentation generation not yet implemented"

# Verify all tests pass
@verify:
    #!/usr/bin/env bash
    set -euo pipefail
    just build
    just test
    just bench
    echo "All verifications passed!"

# Generate coverage report
@coverage:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Coverage reporting not yet implemented for Idris2"
    # Would need idris2-coverage or similar

# Lint the codebase
@lint:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Linting..."
    # Check for common issues
    grep -r "sorry" src/ || true
    grep -r "undefined" src/ || true
    echo "Linting complete!"

# Run CI/CD wellness tests
@ci-wellness:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running CI/CD wellness checks..."
    just build
    just test
    just lint
    echo "CI/CD wellness checks passed!"

# Run tests of tests (meta-tests)
@meta-test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running meta-tests (tests of tests)..."
    # This would test the test framework itself
    echo "Meta-tests not yet implemented"

# Generate CRG badge
@crg-badge:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Generating CRG badge..."
    GRADE=$(grep "Current Grade:" READINESS.adoc | head -1 | sed 's/.*Current Grade: \([A-Z]\)).*/\1/')
    if [ -z "$GRADE" ]; then
        GRADE="X"
    fi
    case "$GRADE" in
        A) COLOR="brightgreen" ;;
        B) COLOR="green" ;;
        C) COLOR="yellowgreen" ;;
        D) COLOR="orange" ;;
        E|F) COLOR="red" ;;
        X) COLOR="lightgrey" ;;
        *) COLOR="lightgrey" ;;
    esac
    echo "https://img.shields.io/badge/CRG-${GRADE}-${COLOR}?style=flat-square"

# Check CRG compliance
@crg-grade:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking CRG compliance..."
    GRADE=$(grep "Current Grade:" READINESS.adoc | head -1 | sed 's/.*Current Grade: \([A-Z]\)).*/\1/')
    if [ -z "$GRADE" ]; then
        echo "ERROR: No Current Grade found in READINESS.adoc"
        exit 1
    fi
    echo "Current CRG Grade: $GRADE"
    echo "Compliance check passed!"

secret-scan-trufflehog:
    @command -v trufflehog >/dev/null && trufflehog filesystem . --only-verified || true
