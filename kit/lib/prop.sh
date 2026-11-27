#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# prop.sh — property-based (PBT). A property must hold over many seeded generated inputs.
#   prop.sh [--runs N] [--seed S] --gen GENCMD -- CHECKCMD...
# GENCMD (run through bash -c, seed in $PTB_SEED) prints one input; CHECKCMD reads it on stdin
# and exits 0 iff the property holds. Pass 0: all N runs (default 100) held. Fail 1: a run
# failed; the seed is printed so it replays. Exit 2: nothing checked (bad N/seed, GENCMD or
# CHECKCMD missing, generator silent or failing, usage).
set -u
runs=100; seed=1; gen=""; cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --runs) [[ $# -ge 2 ]] || break; runs="$2"; shift 2 ;;
  --seed) [[ $# -ge 2 ]] || break; seed="$2"; shift 2 ;;
  --gen)  [[ $# -ge 2 ]] || break; gen="$2"; shift 2 ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
nocheck() { echo "NO CHECK PERFORMED: $1" >&2; exit 2; }
[[ -n "$gen" ]] && [[ "${#cmd[@]}" -gt 0 ]] || nocheck "usage: prop.sh [--runs N] [--seed S] --gen GENCMD -- CHECKCMD..."
[[ "$runs" =~ ^[0-9]+$ ]] && [[ "$runs" -gt 0 ]] || nocheck "bad --runs $runs"
[[ "$seed" =~ ^[0-9]+$ ]] || nocheck "bad --seed $seed"
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || nocheck "${cmd[0]} not found"
inp=$(mktemp) || nocheck "mktemp failed"; trap 'rm -f "$inp"' EXIT
for ((i = 0; i < runs; i++)); do
  s=$((seed + i))
  PTB_SEED=$s bash -c "$gen" >"$inp" 2>/dev/null || nocheck "generator failed at seed $s"
  [[ -s "$inp" ]] || nocheck "generator produced no input at seed $s"
  if ! "${cmd[@]}" <"$inp" >/dev/null 2>&1; then echo "PROPERTY FAIL at seed $s (replay: --runs 1 --seed $s)" >&2; exit 1; fi
done
echo "PROPERTY OK: $runs runs from seed $seed"
