#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Mutation self-check (MUT) of the kit's own libs: each kit/mutations/<lib>.muts is run against
# kit/lib/<lib>.sh with the self-test that covers it; every lib must score >= 80%.
# Exit 0 all pass; 1 a lib below threshold; 2 a lib could not be checked (never a pass).
set -u
cd "$(dirname "$0")/.." || exit 2
declare -A T=([drift]=sweep2 [regression]=sweep2 [contract]=sweep2b [proofreg]=sweep2b [aspect]=sweep2b [dogfood]=sweep4c [enum-drift]=sweep4c [roundtrip]=sweep4c [corpus]=sweep4c [schema-diff]=sweep4c [decay]=sweep4c [xprover]=sweep4c)
rc=0
for lib in "${!T[@]}"; do
  echo "== $lib"
  kit/lib/mutate.sh --target "kit/lib/$lib.sh" --mutations "kit/mutations/$lib.muts" --min-score 80 -- bash "kit/test/${T[$lib]}.test.sh"; r=$?
  [[ "$r" -eq 0 ]] || { rc=$r; [[ "$r" -eq 2 ]] && { echo "NO CHECK PERFORMED for $lib" >&2; exit 2; }; }
done
exit "$rc"
