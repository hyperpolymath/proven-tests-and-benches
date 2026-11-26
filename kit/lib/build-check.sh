#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# build-check.sh — language-agnostic build test (BLD) + build-time bench (B-BLD).
#   build-check.sh --artifact PATH [--bench-out FILE.tsv] [--bench-name NAME] -- BUILD_CMD...
# Runs the build from whatever state the caller prepared (CI: clean checkout),
# requires exit 0, requires PATH to exist and be non-empty, and refuses a build
# that "succeeded" while leaving a stale artefact older than the build start.
# With --bench-out, appends "NAME<TAB>SECONDS<TAB>lower" for sixsigma.sh.
# Exit 0 pass; 1 build/artefact failure; 2 no check performed.
set -u
art=""; out=""; name="build_seconds"
while [ $# -gt 0 ]; do case "$1" in --artifact) art="$2"; shift 2 ;; --bench-out) out="$2"; shift 2 ;; --bench-name) name="$2"; shift 2 ;; --) shift; break ;; *) break ;; esac; done
[ -n "$art" ] && [ $# -gt 0 ] || { echo "NO CHECK PERFORMED: usage: build-check.sh --artifact PATH -- CMD..." >&2; exit 2; }
start=$(date +%s.%N); marker=$(mktemp); touch -d "@$(( $(date +%s) - 1 ))" "$marker"   # 1s slack: coarse mtimes
"$@" || { echo "BUILD FAIL: $*" >&2; rm -f "$marker"; exit 1; }
end=$(date +%s.%N)
[ -s "$art" ] || { echo "BUILD FAIL: artefact $art missing or empty after a build that exited 0" >&2; rm -f "$marker"; exit 1; }
[ "$art" -nt "$marker" ] || [ -d "$art" ] || { echo "BUILD FAIL: artefact $art is stale (not rebuilt)" >&2; rm -f "$marker"; exit 1; }
rm -f "$marker"
[ -z "$out" ] || awk -v s="$start" -v e="$end" -v n="$name" 'BEGIN{printf "%s\t%.3f\tlower\n", n, e-s}' >> "$out"
echo "BUILD OK: $art"
