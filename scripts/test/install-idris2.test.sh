#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
set -euo pipefail
cd "$(dirname "$0")/../.."
for version in 0.7.0 v0.7.0; do
  result=$(IDRIS2_VERSION="$version" bash scripts/install-idris2.sh --source-ref 2>/dev/null)
  [[ "$result" == v0.7.0 ]] || exit 1
done
for version in main vv0.7.0 0.7 '0.7.0;echo injected'; do
  rc=0
  IDRIS2_VERSION="$version" bash scripts/install-idris2.sh --source-ref >/dev/null 2>&1 || rc=$?
  [[ "$rc" == 2 ]] || exit 1
done
rc=0
bash scripts/install-idris2.sh --unknown >/dev/null 2>&1 || rc=$?
[[ "$rc" == 2 ]] || exit 1
echo 'PASS: two release forms accepted; four invalid refs and unknown option rejected'
