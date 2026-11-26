#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# check-coverage.sh — fail-closed check of a repo's coverage manifest.
#
# Usage: kit/check-coverage.sh [--root DIR] [--through-sweep N] [MANIFEST]
#   MANIFEST defaults to <root>/.proven/coverage.tsv
#
# Manifest: tab-separated, '#' comments, columns:
#   id <TAB> status <TAB> language <TAB> ref
#   status   covered | na | planned
#   covered  ref = path (relative to root) of an existing, non-empty file
#   na       ref = written reason, at least 20 characters, not a placeholder
#   planned  ref = 's1'..'s4' (optionally followed by text): the sweep that will cover it.
#            Honest progress, not a pass: a planned row whose sweep is <= --through-sweep
#            is a VIOLATION (it was due). Default --through-sweep is 4, so by default
#            every planned row fails; a repo on sweep 1 gates with --through-sweep 1.
#   language the language of the test, or '-' for na rows
# Every id in kit/ids.tsv (18 categories, 14 aspects, 7 bench kinds) must have at
# least one row. A missing id is a FAILURE, not a pass (A3 G3 / ER-A8 / DOG-01).
#
# Exit: 0 all ids accounted for; 1 violation; 2 no check performed
# (manifest missing/unreadable/empty, or ids.tsv missing). 2 is never a pass.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="."
through=4
manifest=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="$2"; shift 2 ;;
    --through-sweep) through="$2"; shift 2 ;;
    *) manifest="$1"; shift ;;
  esac
done
case "$through" in 1|2|3|4) ;; *) echo "NO CHECK PERFORMED: --through-sweep must be 1-4" >&2; exit 2 ;; esac
[ -n "$manifest" ] || manifest="$root/.proven/coverage.tsv"
ids="$here/ids.tsv"
[ -r "$ids" ] || { echo "NO CHECK PERFORMED: $ids unreadable" >&2; exit 2; }
[ -r "$manifest" ] || { echo "NO CHECK PERFORMED: manifest $manifest missing or unreadable" >&2; exit 2; }
rows=$(grep -vc -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$manifest")
[ "$rows" -gt 0 ] || { echo "NO CHECK PERFORMED: manifest $manifest has no rows" >&2; exit 2; }

awk -F'\t' -v through="$through" -v root="$root" -v idsfile="$ids" '
function bad(msg) { print "VIOLATION: " msg > "/dev/stderr"; fails++ }
BEGIN {
  while ((getline line < idsfile) > 0) {
    if (line ~ /^#/ || line ~ /^[[:space:]]*$/) continue
    split(line, f, "\t"); known[f[2]] = f[1]; order[++n] = f[2]
  }
  split("n/a na none todo tbd tba later later. - n.a. not-applicable", ph, " ")
  for (i in ph) placeholder[ph[i]] = 1
}
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
{
  id = $1; st = $2; lang = $3; ref = $4
  if (!(id in known)) { bad("line " NR ": unknown id \"" id "\""); next }
  if (st == "covered") {
    if (lang == "" || lang == "-") bad("line " NR ": " id " covered but language missing")
    p = (ref ~ /^\//) ? ref : root "/" ref
    cmd = "test -s \"" p "\""
    if (system(cmd) != 0) bad("line " NR ": " id " covered but ref \"" ref "\" is missing or empty")
    else seen[id] = 1
  } else if (st == "na") {
    r = ref; gsub(/^[ \t]+|[ \t]+$/, "", r)
    if (length(r) < 20 || (tolower(r) in placeholder)) bad("line " NR ": " id " na without a real reason (need >= 20 chars)")
    else seen[id] = 1
  } else if (st == "planned") {
    if (ref !~ /^s[1-4]([ \t]|$)/) bad("line " NR ": " id " planned needs ref s1..s4 (the sweep that covers it)")
    else {
      sw = substr(ref, 2, 1) + 0
      if (sw <= through) bad("line " NR ": " id " planned for sweep " sw " but sweeps through " through " are due")
      else { planned[id] = sw; seen[id] = 1; np++ }
    }
  } else bad("line " NR ": " id " status \"" st "\" is not covered|na|planned")
}
END {
  for (i = 1; i <= n; i++) if (!(order[i] in seen)) bad("id " order[i] " (" known[order[i]] ") has no valid row - absence is a failure")
  if (fails > 0) { print fails " violation(s)" > "/dev/stderr"; exit 1 }
  if (np > 0) print "OK through sweep " through ": all " n " ids accounted for, " np " planned for later sweeps (not covered yet)"
  else print "OK: all " n " ids accounted for"
}' "$manifest"
