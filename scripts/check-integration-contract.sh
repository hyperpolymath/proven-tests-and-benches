#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Downstream integration contract conformance gate.
#
# Runs the normative checker over both surfaces and then the minimal
# downstream fixture end to end. Cheap and toolchain-free, so a contract
# regression fails in seconds rather than after the Idris2 bootstrap.
#
# Exit codes (the repository's standing three-outcome convention):
#   0  every case ran and held
#   1  at least one case produced the wrong verdict
#   2  NO CHECK WAS PERFORMED — a required tool or file is missing

set -uo pipefail

cd "$(dirname "$0")/.." || {
  echo "check-integration-contract: cannot reach repository root" >&2
  exit 2
}

if ! command -v python3 >/dev/null 2>&1; then
  echo "check-integration-contract: python3 is required but was not found" >&2
  exit 2
fi

status=0

echo "== proven-tests submission contract =="
rc=0
python3 integrations/contract/check_contract.py proven-tests || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "check-integration-contract: NO CHECK WAS PERFORMED (proven-tests, exit 2)" >&2
  exit 2
fi
if [ "$rc" -ne 0 ]; then
  status=1
fi

echo
echo "== cicd-squabbler legitimate-green contract =="
rc=0
python3 integrations/contract/check_contract.py cicd-squabbler || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "check-integration-contract: NO CHECK WAS PERFORMED (cicd-squabbler, exit 2)" >&2
  exit 2
fi
if [ "$rc" -ne 0 ]; then
  status=1
fi

echo
echo "== minimal downstream fixture (emit + validate) =="
rc=0
bash integrations/contract/proven-tests/downstream/run.sh || rc=$?
if [ "$rc" -eq 2 ]; then
  echo "check-integration-contract: NO CHECK WAS PERFORMED (downstream fixture, exit 2)" >&2
  exit 2
fi
if [ "$rc" -ne 0 ]; then
  echo "check-integration-contract: downstream fixture exited $rc" >&2
  status=1
fi

if [ "$status" -ne 0 ]; then
  echo
  echo "FAIL: the downstream integration contract does not hold." >&2
  exit 1
fi

echo
echo "OK: downstream integration contract conformance"
