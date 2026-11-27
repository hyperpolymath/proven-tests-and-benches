#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for EXE (execution and runtime) and CHS (chaos/resilience) of the kit libs.
root="$(cd "$(dirname "$0")/../.." && pwd)"
. "$root/kit/lib/ptb.sh"
L="$root/kit/lib"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
CLEAN=(env -i PATH=/usr/bin:/bin)
# ---- EXE: a clean environment, and from another working directory
ptb_eq exe-clean-env-contract   0 "$(code "${CLEAN[@]}" bash "$L/contract.sh" --require hello -- echo hello)"
ptb_eq exe-clean-env-regression 0 "$(echo hi > "$tmp/g"; code "${CLEAN[@]}" bash "$L/regression.sh" --golden "$tmp/g" -- echo hi)"
ptb_eq exe-clean-env-prop       0 "$(code "${CLEAN[@]}" bash "$L/prop.sh" --runs 5 --gen 'echo $PTB_SEED' -- cat)"
ptb_eq exe-clean-env-fuzz       0 "$(code "${CLEAN[@]}" bash "$L/fuzz.sh" --runs 5 -- cat)"
ptb_eq exe-clean-env-bench-kit  0 "$(code "${CLEAN[@]}" bash "$root/benchmarks/kit/bench-kit.sh" B-LAT)"
mkdir -p "$tmp/b"; for i in 1 2 3; do printf 'lat\t100\tlower\n' > "$tmp/b/0000000$i.tsv"; done
ptb_eq exe-other-cwd-bench      0 "$(cd / && code bash "$L/bench.sh" --kind B-LAT --baseline-dir "$tmp/b" -- bash -c "printf 'lat\t100\tlower\n'")"
ptb_eq exe-lib-is-executable    0 "$(for f in "$L"/*.sh; do [[ -x "$f" ]] || { echo 1; exit; }; done; echo 0)"
# ---- CHS: hostile conditions must fail closed (2), never pass
BAD=(env TMPDIR=/nonexistent/dir)
echo x > "$tmp/c"
ptb_eq chs-no-tmp-drift     2 "$(code "${BAD[@]}" bash "$L/drift.sh" --generated-by echo x --committed "$tmp/c")"
ptb_eq chs-no-tmp-bench     2 "$(code "${BAD[@]}" bash "$L/bench.sh" --kind B-LAT --baseline-dir "$tmp/b" -- true)"
ptb_eq chs-no-tmp-fuzz      2 "$(code "${BAD[@]}" bash "$L/fuzz.sh" --runs 1 -- cat)"
ptb_eq chs-no-tmp-prop      2 "$(code "${BAD[@]}" bash "$L/prop.sh" --runs 1 --gen 'echo x' -- cat)"
ptb_eq chs-no-tmp-mutate    2 "$(code "${BAD[@]}" bash "$L/mutate.sh" --target "$tmp/c" --mutations "$tmp/c" -- true)"
# SIGTERM mid-mutation must leave the target restored
printf 'echo $(( $1 + $2 ))\n' > "$tmp/t.sh"; cp "$tmp/t.sh" "$tmp/t.orig"; printf 's/+/-/\n' > "$tmp/m"
bash "$L/mutate.sh" --target "$tmp/t.sh" --mutations "$tmp/m" -- bash -c 'grep -q -- "-" "$0" && sleep 30; true' "$tmp/t.sh" >/dev/null 2>&1 &
mp=$!; sleep 1.5; pkill -TERM -P "$mp" sleep 2>/dev/null; kill -TERM "$mp" 2>/dev/null; wait "$mp" 2>/dev/null
ptb_eq chs-sigterm-restores-target 0 "$(cmp -s "$tmp/t.sh" "$tmp/t.orig"; echo $?)"
# odd paths and big inputs
mkdir "$tmp/we ird [x]"; echo hi > "$tmp/we ird [x]/g o.txt"
ptb_eq chs-odd-path-regression 0 "$(code bash "$L/regression.sh" --golden "$tmp/we ird [x]/g o.txt" -- echo hi)"
ptb_eq chs-big-input-fuzz      0 "$(code bash "$L/fuzz.sh" --runs 3 --max-bytes 200000 -- cat)"
# two mutation runs in parallel on separate targets both complete correctly
for n in a b; do printf 'echo $(( $1 + $2 ))\n' > "$tmp/$n.sh"; done
( bash "$L/mutate.sh" --target "$tmp/a.sh" --mutations "$tmp/m" --min-score 100 -- bash -c '[[ "$(bash "$0" 2 3)" == 5 ]]' "$tmp/a.sh" >/dev/null 2>&1; echo $? > "$tmp/ra" ) &
( bash "$L/mutate.sh" --target "$tmp/b.sh" --mutations "$tmp/m" --min-score 100 -- bash -c '[[ "$(bash "$0" 2 3)" == 5 ]]' "$tmp/b.sh" >/dev/null 2>&1; echo $? > "$tmp/rb" ) &
wait
ptb_eq chs-parallel-mutate-a 0 "$(cat "$tmp/ra")"
ptb_eq chs-parallel-mutate-b 0 "$(cat "$tmp/rb")"
ptb_done
