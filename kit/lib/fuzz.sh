#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# fuzz.sh — fuzz (FUZ). Feed seeded random bytes to a command; it must never crash or hang.
#   fuzz.sh [--runs N] [--seed S] [--max-bytes B] [--ok-exit LIST] [--timeout SECS] -- CMD...
# CMD reads stdin. An exit code in LIST (default "0,1,2": clean accept or clean reject) is fine.
# Any other code (signal death, 124 timeout, panic exit) is a finding. Pass 0: no findings in N
# runs (default 200). Fail 1: finding, with a replayable seed. Exit 2: nothing checked.
set -u
runs=200; seed=1; maxb=256; ok="0,1,2"; to=10; cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --runs) [[ $# -ge 2 ]] || break; runs="$2"; shift 2 ;;
  --seed) [[ $# -ge 2 ]] || break; seed="$2"; shift 2 ;;
  --max-bytes) [[ $# -ge 2 ]] || break; maxb="$2"; shift 2 ;;
  --ok-exit) [[ $# -ge 2 ]] || break; ok="$2"; shift 2 ;;
  --timeout) [[ $# -ge 2 ]] || break; to="$2"; shift 2 ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
nocheck() { echo "NO CHECK PERFORMED: $1" >&2; exit 2; }
[[ "${#cmd[@]}" -gt 0 ]] || nocheck "usage: fuzz.sh [opts] -- CMD..."
for v in runs seed maxb to; do [[ "${!v}" =~ ^[0-9]+$ ]] && [[ "${!v}" -gt 0 || "$v" == seed ]] || nocheck "bad numeric option $v=${!v}"; done
[[ "$ok" =~ ^[0-9]+(,[0-9]+)*$ ]] || nocheck "bad --ok-exit $ok"
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || nocheck "${cmd[0]} not found"
command -v timeout >/dev/null 2>&1 || nocheck "timeout(1) not available"
inp=$(mktemp) || nocheck "mktemp failed"; trap 'rm -f "$inp"' EXIT
for ((i = 0; i < runs; i++)); do
  s=$((seed + i))
  LC_ALL=C awk -v s="$s" -v m="$maxb" 'BEGIN { srand(s); n = 1 + int(rand() * m); for (k = 0; k < n; k++) printf "%c", 1 + int(rand() * 255) }' >"$inp" 2>/dev/null
  [[ -s "$inp" ]] || nocheck "input generation failed at seed $s"
  timeout "$to" "${cmd[@]}" <"$inp" >/dev/null 2>&1; rc=$?
  case ",$ok," in *",$rc,"*) ;; *) echo "FUZZ FINDING: exit $rc at seed $s (replay: --runs 1 --seed $s)" >&2; exit 1 ;; esac
done
echo "FUZZ OK: $runs runs from seed $seed, no crash/hang"
