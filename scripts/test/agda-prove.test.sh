#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Self-test: the good file proves; the false claim and the doubtful file are
# REJECTED; an empty directory is "no check", not a pass.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
p="$root/scripts/agda-prove.sh"; fx="$root/agda/fixtures"
pass=0; fail=0
want() { local n="$1" c="$2"; shift 2; "$@" >/dev/null 2>&1; g=$?
  if [ "$g" -eq "$c" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $n: want $c got $g"; fi; }
want good-file-proves             0 "$p" "$fx/good"
want false-claim-rejected         1 "$p" "$fx/false-claim"
want doubtful-file-rejected       1 "$p" "$fx/doubtful"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
want no-sources-is-no-check       2 "$p" "$tmp"
# an exception with no real reason must itself be a violation
# (isolated: the fixture is otherwise audit-clean, so only the short reason can fail it)
printf 'Good.agda\tpostulate\tbad\n' > "$tmp/allow.tsv"
want allow-without-reason-fails   1 "$root/scripts/agda-doubt-check.sh" --allow "$tmp/allow.tsv" "$fx/good"
printf 'Good.agda\tpostulate\tjustified in writing, twenty chars+\n' > "$tmp/allow-ok.tsv"
want allow-with-reason-control    0 "$root/scripts/agda-doubt-check.sh" --allow "$tmp/allow-ok.tsv" "$fx/good"
want allow-without-file-is-2      2 "$p" --allow
want missing-target-is-2          2 "$p" "$fx/good" "$tmp/does-not-exist"
echo "agda-prove self-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && [ "$pass" -ge 8 ]
