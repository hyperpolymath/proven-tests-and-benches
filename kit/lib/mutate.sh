#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# mutate.sh — mutation testing (MUT). The tests must notice deliberate breakage of the target.
#   mutate.sh --target FILE --mutations FILE [--min-score PCT] -- TESTCMD...
# MUTATIONS rows: one sed expression per line (# comments and blanks ignored). Each is applied
# to FILE in turn (FILE is always restored); TESTCMD must then FAIL (mutant killed). A mutation
# that changes nothing is skipped, not counted. Score = killed / applied. Pass 0: score >=
# PCT (default 80). Fail 1: below it, survivors listed. Exit 2: nothing checked (TESTCMD already
# failing on the unmutated target, no mutation applied, bad input, usage).
set -u
tgt=""; mf=""; min=80; cmd=()
while [[ $# -gt 0 ]]; do case "$1" in
  --target) [[ $# -ge 2 ]] || break; tgt="$2"; shift 2 ;;
  --mutations) [[ $# -ge 2 ]] || break; mf="$2"; shift 2 ;;
  --min-score) [[ $# -ge 2 ]] || break; min="$2"; shift 2 ;;
  --) shift; cmd=("$@"); break ;;
  *) break ;; esac; done
nocheck() { echo "NO CHECK PERFORMED: $1" >&2; exit 2; }
[[ -n "$tgt" ]] && [[ -n "$mf" ]] && [[ "${#cmd[@]}" -gt 0 ]] || nocheck "usage: mutate.sh --target FILE --mutations FILE [--min-score PCT] -- TESTCMD..."
[[ -f "$tgt" ]] && [[ -r "$mf" ]] || nocheck "target or mutations file unreadable"
[[ "$min" =~ ^[0-9]+$ ]] && [[ "$min" -le 100 ]] || nocheck "bad --min-score $min"
command -v "${cmd[0]}" >/dev/null 2>&1 || [[ -x "${cmd[0]}" ]] || nocheck "${cmd[0]} not found"
orig=$(mktemp) || nocheck "mktemp failed"; cp -p "$tgt" "$orig"
trap 'cp -p "$orig" "$tgt"; rm -f "$orig"' EXIT
"${cmd[@]}" >/dev/null 2>&1 || nocheck "tests already fail on the unmutated target"
applied=0; killed=0; surv=()
while IFS= read -r m; do
  [[ -n "${m//[[:space:]]/}" ]] && [[ "$m" != \#* ]] || continue
  sed -e "$m" "$orig" >"$tgt" 2>/dev/null || { cp -p "$orig" "$tgt"; nocheck "bad sed expression: $m"; }
  if cmp -s "$orig" "$tgt"; then continue; fi
  applied=$((applied + 1))
  if "${cmd[@]}" >/dev/null 2>&1; then surv+=("$m"); else killed=$((killed + 1)); fi
  cp -p "$orig" "$tgt"
done <"$mf"
[[ "$applied" -gt 0 ]] || nocheck "no mutation changed the target"
score=$((killed * 100 / applied))
echo "MUTATION: killed $killed/$applied = ${score}% (min $min%)"
if [[ "$score" -lt "$min" ]]; then for m in "${surv[@]}"; do echo "SURVIVED: $m" >&2; done; exit 1; fi
