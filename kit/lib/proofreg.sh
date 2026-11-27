#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# proofreg.sh — proof regression (PRF). Every proof claim recorded must still be proved.
#   proofreg.sh --claims FILE -- CMD...
# FILE lists one claim id per line (blank lines and #-comments ignored). CMD (the prover run)
# must succeed and print each claim id on stdout. Pass 0: all claims present. Fail 1: CMD
# fails or a claim has vanished (a silently dropped proof is a regression).
# Exit 2: nothing checked (no claims, CMD missing, usage).
set -u
cl=""; cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --claims) [[ $# -ge 2 ]] || break; cl="$2"; shift 2 ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
[[ -n "$cl" ]] && [[ "${#cmd[@]}" -gt 0 ]] || { echo "NO CHECK PERFORMED: usage: proofreg.sh --claims FILE -- CMD..." >&2; exit 2; }
[[ -r "$cl" ]] || { echo "NO CHECK PERFORMED: claims file $cl unreadable" >&2; exit 2; }
claims=$(grep -Ev '^[[:space:]]*(#|$)' "$cl")
[[ -n "$claims" ]] || { echo "NO CHECK PERFORMED: claims file has no claims" >&2; exit 2; }
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || { echo "NO CHECK PERFORMED: ${cmd[0]} not found" >&2; exit 2; }
out=$("${cmd[@]}" 2>/dev/null) || { echo "PROOFREG FAIL: prover run failed: ${cmd[*]}" >&2; exit 1; }
bad=0
while IFS= read -r c; do grep -qFx -- "$c" <<<"$out" || { echo "PROOFREG FAIL: claim vanished: $c" >&2; bad=1; }; done <<<"$claims"
[[ "$bad" -eq 0 ]] && echo "PROOFREG OK" || exit 1
