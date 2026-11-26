#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Self-test for kit/check-coverage.sh. Each negative case must fail the way
# stated; a checker that passes everything would pass the positive case too,
# so the negative cases are the evidence.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
chk="$here/check-coverage.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
expect() { # name want_exit cmd...
  local name="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $name: want exit $want got $got"; fi
}
mkdir -p "$tmp/r/t"; echo 'x' > "$tmp/r/t/real.sh"
full() { # emit a complete manifest, every id na with a real reason
  awk -F'\t' '!/^#/ && NF==3 {printf "%s\tna\t-\tThis id does not apply to the fixture repo\n",$2}' "$here/ids.tsv"
}
full > "$tmp/ok.tsv"
expect complete-manifest-passes 0 "$chk" --root "$tmp/r" "$tmp/ok.tsv"
# covered row pointing at a real file
sed 's|^UT\tna.*|UT\tcovered\tbash\tt/real.sh|' "$tmp/ok.tsv" > "$tmp/cov.tsv"
expect covered-real-file-passes 0 "$chk" --root "$tmp/r" "$tmp/cov.tsv"
# covered row pointing at a missing file
sed 's|^UT\tna.*|UT\tcovered\tbash\tt/ghost.sh|' "$tmp/ok.tsv" > "$tmp/ghost.tsv"
expect covered-missing-file-fails 1 "$chk" --root "$tmp/r" "$tmp/ghost.tsv"
# covered row pointing at an empty file
: > "$tmp/r/t/empty.sh"
sed 's|^UT\tna.*|UT\tcovered\tbash\tt/empty.sh|' "$tmp/ok.tsv" > "$tmp/empty.tsv"
expect covered-empty-file-fails 1 "$chk" --root "$tmp/r" "$tmp/empty.tsv"
# one id absent
grep -v '^FUZ' "$tmp/ok.tsv" > "$tmp/absent.tsv"
expect absent-id-fails 1 "$chk" --root "$tmp/r" "$tmp/absent.tsv"
# na with placeholder / short reason
sed 's|^FUZ\tna.*|FUZ\tna\t-\tn/a|' "$tmp/ok.tsv" > "$tmp/short.tsv"
expect short-na-reason-fails 1 "$chk" --root "$tmp/r" "$tmp/short.tsv"
# unknown id
{ cat "$tmp/ok.tsv"; printf 'ZZZ\tna\t-\tThis id is not in the taxonomy at all\n'; } > "$tmp/unk.tsv"
expect unknown-id-fails 1 "$chk" --root "$tmp/r" "$tmp/unk.tsv"
# bad status
sed 's|^FUZ\tna|FUZ\tskipped|' "$tmp/ok.tsv" > "$tmp/st.tsv"
expect bad-status-fails 1 "$chk" --root "$tmp/r" "$tmp/st.tsv"
# no check performed -> 2, never 0
expect missing-manifest-is-2 2 "$chk" --root "$tmp/r" "$tmp/nope.tsv"
printf '# only a comment\n' > "$tmp/comment.tsv"
expect comment-only-manifest-is-2 2 "$chk" --root "$tmp/r" "$tmp/comment.tsv"
echo "check-coverage self-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ] && [ "$pass" -ge 10 ]
