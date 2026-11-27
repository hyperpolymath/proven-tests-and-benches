#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for the sweep 3 kit libs: prop, fuzz, mutate, lifecycle, compat (negative controls included).
here="$(cd "$(dirname "$0")/../lib" && pwd)"
. "$here/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
# PBT: gen prints a number from the seed; property = number is even (always) / below 50 (sometimes false)
ptb_eq prop-holds      0 "$(code "$here/prop.sh" --runs 20 --gen 'echo $((PTB_SEED*2))' -- bash -c 'read n; (( n % 2 == 0 ))')"
ptb_eq prop-violated   1 "$(code "$here/prop.sh" --runs 100 --gen 'echo $PTB_SEED' -- bash -c 'read n; (( n < 50 ))')"
ptb_eq prop-replay     1 "$(code "$here/prop.sh" --runs 1 --seed 60 --gen 'echo $PTB_SEED' -- bash -c 'read n; (( n < 50 ))')"
ptb_eq prop-gen-fails  2 "$(code "$here/prop.sh" --gen 'exit 3' -- true)"
ptb_eq prop-gen-silent 2 "$(code "$here/prop.sh" --gen 'true' -- true)"
ptb_eq prop-bad-runs   2 "$(code "$here/prop.sh" --runs 0 --gen 'echo x' -- true)"
ptb_eq prop-no-cmd     2 "$(code "$here/prop.sh" --gen 'echo x' -- /no/such/bin)"
ptb_eq prop-usage      2 "$(code "$here/prop.sh")"
# FUZ
ptb_eq fuzz-robust     0 "$(code "$here/fuzz.sh" --runs 20 -- cat)"
ptb_eq fuzz-crash      1 "$(code "$here/fuzz.sh" --runs 5 -- bash -c 'kill -SEGV $$')"
ptb_eq fuzz-bad-exit   1 "$(code "$here/fuzz.sh" --runs 5 -- bash -c 'exit 42')"
ptb_eq fuzz-ok-exit    0 "$(code "$here/fuzz.sh" --runs 5 --ok-exit 42 -- bash -c 'exit 42')"
ptb_eq fuzz-hang       1 "$(code "$here/fuzz.sh" --runs 1 --timeout 1 -- sleep 5)"
ptb_eq fuzz-bad-ok     2 "$(code "$here/fuzz.sh" --ok-exit x -- cat)"
ptb_eq fuzz-no-cmd     2 "$(code "$here/fuzz.sh" -- /no/such/bin)"
ptb_eq fuzz-usage      2 "$(code "$here/fuzz.sh")"
# MUT
printf '#!/usr/bin/env bash\n# note: adds\necho $(( $1 + $2 ))\n' > "$tmp/add.sh"
printf 's/+/-/\ns/+/*/\ns/# note/# NOTE/\ns/zzz/y/\n' > "$tmp/muts"
cp "$tmp/add.sh" "$tmp/add.orig"
T=(bash -c '[ "$(bash '"$tmp"'/add.sh 2 3)" = 5 ]')
ptb_eq mut-below-80    1 "$(code "$here/mutate.sh" --target "$tmp/add.sh" --mutations "$tmp/muts" -- "${T[@]}")"
ptb_eq mut-restored    0 "$(cmp -s "$tmp/add.sh" "$tmp/add.orig"; echo $?)"
ptb_eq mut-min-60      0 "$(code "$here/mutate.sh" --target "$tmp/add.sh" --mutations "$tmp/muts" --min-score 60 -- "${T[@]}")"
printf 's/zzz/y/\n' > "$tmp/noop"
ptb_eq mut-none-apply  2 "$(code "$here/mutate.sh" --target "$tmp/add.sh" --mutations "$tmp/noop" -- "${T[@]}")"
ptb_eq mut-tests-red   2 "$(code "$here/mutate.sh" --target "$tmp/add.sh" --mutations "$tmp/muts" -- false)"
ptb_eq mut-no-target   2 "$(code "$here/mutate.sh" --target "$tmp/none" --mutations "$tmp/muts" -- true)"
ptb_eq mut-usage       2 "$(code "$here/mutate.sh")"
# LCY
ptb_eq lcy-ok          0 "$(code "$here/lifecycle.sh" --setup true --use true --use true --teardown true)"
ptb_eq lcy-use-fails   1 "$(code "$here/lifecycle.sh" --use true --use false)"
ptb_eq lcy-setup-fails 1 "$(code "$here/lifecycle.sh" --setup false --use true)"
ptb_eq lcy-td-fails    1 "$(code "$here/lifecycle.sh" --use true --teardown false)"
: > "$tmp/td-ran"; rm "$tmp/td-ran"
code "$here/lifecycle.sh" --use false --teardown "touch $tmp/td-ran" >/dev/null
ptb_eq lcy-td-always   0 "$([[ -f "$tmp/td-ran" ]]; echo $?)"
code "$here/lifecycle.sh" --setup false --use "touch $tmp/skipped" >/dev/null
ptb_eq lcy-setup-skips 1 "$([[ -f "$tmp/skipped" ]]; echo $?)"
ptb_eq lcy-no-use      2 "$(code "$here/lifecycle.sh" --setup true)"
ptb_eq lcy-usage       2 "$(code "$here/lifecycle.sh" --bogus)"
# CMP
printf 'a\tFOO=1\nb\tFOO=1 BAR=2\n' > "$tmp/mx"; printf 'a\tFOO=1\nb\tFOO=2\n' > "$tmp/mx-bad"
printf '# only\n' > "$tmp/mx-empty"; printf 'a\tnotanassign\n' > "$tmp/mx-malf"
ptb_eq cmp-all-pass    0 "$(code "$here/compat.sh" --matrix "$tmp/mx" -- bash -c '[ "$FOO" = 1 ]')"
ptb_eq cmp-row-fails   1 "$(code "$here/compat.sh" --matrix "$tmp/mx-bad" -- bash -c '[ "$FOO" = 1 ]')"
ptb_eq cmp-empty       2 "$(code "$here/compat.sh" --matrix "$tmp/mx-empty" -- true)"
ptb_eq cmp-malformed   2 "$(code "$here/compat.sh" --matrix "$tmp/mx-malf" -- true)"
ptb_eq cmp-no-matrix   2 "$(code "$here/compat.sh" --matrix "$tmp/none" -- true)"
ptb_eq cmp-no-cmd      2 "$(code "$here/compat.sh" --matrix "$tmp/mx" -- /no/such/bin)"
ptb_eq cmp-usage       2 "$(code "$here/compat.sh")"
ptb_done
