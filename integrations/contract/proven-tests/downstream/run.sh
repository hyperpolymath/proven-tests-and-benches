#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Minimal downstream fixture — the whole CI flow, in one script.
#
# A Rust repository calls this from its own pipeline. It:
#   1. emits a schema_version-2 run report from a flat list of executed test
#      results (example-tests.json stands in for `cargo test` output), and
#   2. validates that report against the integration contract.
#
# The emitter DERIVES coverage from entries that actually passed; the validator
# recomputes it independently and fails on any disagreement. So a report cannot
# claim a cell it did not run, and a tier cannot be claimed without its
# evidence.
#
# EXIT CODES: 0 the report conforms; 1 the report does not; 2 a tool was
# missing or the input unreadable (NO CHECK WAS PERFORMED).

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
contract="$(cd "$here/../.." && pwd)"
out="${1:-$here/build/proven-run-report.json}"
mkdir -p "$(dirname "$out")"

for tool in python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "run.sh: '$tool' is required but was not found" >&2
    exit 2
  }
done

python3 "$here/emit_report.py" "$here/example-tests.json" "$out"
python3 "$contract/check_contract.py" validate-file "$out" proven-tests

echo "downstream fixture: $out conforms to the Proven-Tests integration contract"
