#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for bench.sh: each Six Sigma class and every no-check path.
here="$(cd "$(dirname "$0")/../lib" && pwd)"
. "$here/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
mkdir "$tmp/b" "$tmp/empty"
for i in 01 02 03; do printf 'lat\t100\tlower\n' > "$tmp/b/000000$i-r.tsv"; done
row() { printf 'lat\t%s\tlower\n' "$1"; }
B=(--kind B-LAT --baseline-dir "$tmp/b")
ptb_eq bench-ordinary     0 "$(code "$here/bench.sh" "${B[@]}" -- bash -c "printf 'lat\t105\tlower\n'")"
ptb_eq bench-extraord     0 "$(code "$here/bench.sh" "${B[@]}" -- bash -c "printf 'lat\t50\tlower\n'")"
ptb_eq bench-acceptable-3 3 "$(code "$here/bench.sh" "${B[@]}" -- bash -c "printf 'lat\t130\tlower\n'")"
ptb_eq bench-unaccept-1   1 "$(code "$here/bench.sh" "${B[@]}" -- bash -c "printf 'lat\t200\tlower\n'")"
ptb_eq bench-short-window 2 "$(code "$here/bench.sh" "${B[@]}" --require-full-window -- bash -c "printf 'lat\t100\tlower\n'")"
ptb_eq bench-no-baseline  2 "$(code "$here/bench.sh" --kind B-LAT --baseline-dir "$tmp/empty" -- bash -c "printf 'lat\t100\tlower\n'")"
ptb_eq bench-bad-kind     2 "$(code "$here/bench.sh" --kind B-XXX --baseline-dir "$tmp/b" -- true)"
ptb_eq bench-cmd-fails    2 "$(code "$here/bench.sh" "${B[@]}" -- false)"
ptb_eq bench-cmd-silent   2 "$(code "$here/bench.sh" "${B[@]}" -- true)"
ptb_eq bench-no-cmd       2 "$(code "$here/bench.sh" "${B[@]}" -- /no/such/bin)"
ptb_eq bench-usage        2 "$(code "$here/bench.sh")"
ptb_done
