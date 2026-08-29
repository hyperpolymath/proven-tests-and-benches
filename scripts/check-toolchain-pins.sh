#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Toolchain-pin drift gate.
#
# WHY THIS EXISTS
# ---------------
# On 2026-08-03 this repository declared Idris2 0.8.0 in two machine-readable
# files (META.a2ml ADR-005, STATE.a2ml [build]) and one prose doc, while every
# executable path — the installer, both CI pipelines, the README prerequisites
# — used 0.7.0. The installed compiler was 0.7.0. Nothing detected the split
# because nothing compared the two populations.
#
# This script compares them. It fails loudly on drift. It is deliberately
# grep-based and dependency-free so it can run before any toolchain exists.
#
# Exit codes: 0 = all pins agree, 1 = drift detected, 2 = a pin is missing.

set -uo pipefail
cd "$(dirname "$0")/.." || { echo "FAIL: cannot reach repository root" >&2; exit 2; }

EXPECTED=""
declare -a MISSING=()
declare -a FOUND=()

# ---------------------------------------------------------------------------
# extract <label> <file> <sed-expression>
#   Records the version found, or records the file as missing its pin.
#   Never silently skips: a file that exists but has no pin is an error, not
#   a pass. (Skip-if-absent is exactly how this class of bug survives.)
# ---------------------------------------------------------------------------
extract() {
    local label="$1" file="$2" expr="$3" version=""
    if [ ! -f "$file" ]; then
        MISSING+=("$label ($file): FILE NOT FOUND")
        return
    fi
    version="$(sed -n "$expr" "$file" | head -1)"
    if [ -z "$version" ]; then
        MISSING+=("$label ($file): no Idris2 version pin found")
        return
    fi
    FOUND+=("$version|$label|$file")
}

extract ".tool-versions" \
    ".tool-versions" \
    's/^idris2[[:space:]]\+\([0-9][0-9.]*\).*/\1/p'

extract "installer default" \
    "scripts/install-idris2.sh" \
    's/^IDRIS2_VERSION=.*:-v\?\([0-9][0-9.]*\)}.*/\1/p'

extract "GitHub Actions CI" \
    ".github/workflows/ci.yml" \
    's/.*\(IDRIS2_VERSION:[[:space:]]*\|idris2-\)v\?\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\2/p'

extract "GitLab CI cache key" \
    ".gitlab-ci.yml" \
    's/.*key:[[:space:]]*idris2-toolchain-v\([0-9][0-9.]*\).*/\1/p'

extract "META.a2ml ADR-005" \
    ".machine_readable/descriptiles/META.a2ml" \
    's/.*Toolchain Idris2 \([0-9][0-9.]*\).*/\1/p'

extract "STATE.a2ml [build]" \
    ".machine_readable/descriptiles/STATE.a2ml" \
    's/^toolchain[[:space:]]*=[[:space:]]*"idris2-\([0-9][0-9.]*\)".*/\1/p'

extract "README prerequisites" \
    "README.adoc" \
    's/.*Idris2[[:space:]]*(\?[[:space:]]*v\?\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p'

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
status=0

echo "Idris2 pin declared by each artefact:"
for entry in "${FOUND[@]}"; do
    version="${entry%%|*}"; rest="${entry#*|}"
    label="${rest%%|*}"; file="${rest#*|}"
    printf '  %-24s %-8s (%s)\n' "$label" "$version" "$file"
    if [ -z "$EXPECTED" ]; then
        EXPECTED="$version"
    elif [ "$version" != "$EXPECTED" ]; then
        status=1
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo
    echo "MISSING PINS:"
    printf '  %s\n' "${MISSING[@]}"
    status=2
fi

if [ "$status" -eq 1 ]; then
    echo
    echo "FAIL: toolchain pins disagree. Every artefact above must name one version."
    echo "      Reconcile them, then re-run: just check-pins"
    exit 1
fi

if [ "$status" -eq 2 ]; then
    echo
    echo "FAIL: at least one artefact declares no Idris2 version."
    exit 2
fi

# ---------------------------------------------------------------------------
# If a compiler is on PATH, hold it to the same pin. Absence is not failure
# (this gate must run before provisioning); disagreement is.
# ---------------------------------------------------------------------------
if command -v idris2 >/dev/null 2>&1; then
    installed="$(idris2 --version | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p')"
    echo
    if [ "$installed" = "$EXPECTED" ]; then
        echo "Installed compiler: $installed (agrees)"
    else
        echo "FAIL: installed compiler is $installed but every artefact pins $EXPECTED."
        exit 1
    fi
else
    echo
    echo "Installed compiler: not on PATH (declarative check only)."
fi

echo
echo "OK: all Idris2 pins agree on $EXPECTED"
