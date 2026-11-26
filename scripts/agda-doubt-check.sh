#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# agda-doubt-check.sh — the "doubt check" (BEST HONEST READING; see LATER.adoc D-1).
#
# The owner's term "doubt check" is not defined anywhere in this repo or in
# metadatastician/standards. The reading implemented here: before trusting that
# "it type-checks under --safe" means "it is proved", look for every place a
# proof can quietly stop being a proof — a source-level audit that does NOT
# rely on the compiler, because a flag set in a file can be weakened in the file.
# Each hit is a DOUBT the author must remove or justify in writing.
#
# Usage: agda-doubt-check.sh [--allow FILE] PATH...      (PATH = file or dir)
#   --allow FILE   lines "relative/path.agda<TAB>pattern-id<TAB>reason (>=20 chars)";
#                  a justified, named exception. Anything not listed is a doubt.
# Exit: 0 no doubts; 1 doubts found; 2 no check (no Agda sources found).
set -u
allow=""; paths=()
while [ $# -gt 0 ]; do
  case "$1" in --allow) allow="$2"; shift 2 ;; *) paths+=("$1"); shift ;; esac
done
[ "${#paths[@]}" -gt 0 ] || { echo "NO CHECK PERFORMED: no PATH given" >&2; exit 2; }
mapfile -t files < <(find "${paths[@]}" -type f \( -name '*.agda' -o -name '*.lagda' -o -name '*.lagda.md' -o -name '*.lagda.tex' -o -name '*.lagda.rst' \) 2>/dev/null | sort)
[ "${#files[@]}" -gt 0 ] || { echo "NO CHECK PERFORMED: no Agda sources under ${paths[*]}" >&2; exit 2; }

# id<TAB>ERE (applied per line, comments after -- stripped first)
patterns=$'postulate\t(^|[^[:alnum:]_-])postulate([^[:alnum:]_-]|$)
terminating\t\\{-#[[:space:]]*(NON_)?TERMINATING
no-positivity\t\\{-#[[:space:]]*NO_POSITIVITY_CHECK
no-universe-check\t\\{-#[[:space:]]*NO_UNIVERSE_CHECK
type-in-type\t--(type-in-type|omega-in-omega)
unsound-flag\t--(injective-type-constructors|no-termination-check|no-positivity-check|no-universe-check|allow-unsolved-metas|allow-incomplete-matches|allow-exec|no-pattern-match-coverage)
trustme\tprimTrustMe
builtin-rewrite\t\\{-#[[:space:]]*BUILTIN[[:space:]]+REWRITE
rewrite-rule\t\\{-#[[:space:]]*REWRITE
hole\t(\\{!|[[:space:]]\\?([[:space:]]|$))
foreign\t\\{-#[[:space:]]*(COMPILE|FOREIGN)
unsafe-import\tAgda\\.Builtin\\.TrustMe|Axiom\\.'
fail=0
declare -A allowed
if [ -n "$allow" ]; then
  [ -r "$allow" ] || { echo "NO CHECK PERFORMED: allow file $allow unreadable" >&2; exit 2; }
  while IFS=$'\t' read -r f id reason; do
    case "$f" in ''|\#*) continue ;; esac
    [ "${#reason}" -ge 20 ] || { echo "VIOLATION: allow entry for $f/$id has no real reason" >&2; fail=1; continue; }
    allowed["$f|$id"]=1
  done < "$allow"
fi
for f in "${files[@]}"; do
  # (1) the file itself must opt in to --safe and --cubical-compatible
  opts=$(grep -E '^\{-#[[:space:]]*OPTIONS' "$f" | tr '\n' ' ')
  for need in --safe --cubical-compatible; do
    if ! printf '%s' "$opts" | grep -q -- "$need"; then
      [ -n "${allowed["$f|missing$need"]:-}" ] || { echo "DOUBT $f: OPTIONS pragma does not state $need (a flag only on the command line can be dropped by a caller)" >&2; fail=1; }
    fi
  done
  # (2) per-line pattern scan, '--' line comments stripped (conservative: only
  # after whitespace, so --safe style flags inside OPTIONS are kept)
  while IFS=$'\t' read -r id re; do
    hits=$(sed -E 's/(^|[[:space:]])--([[:space:]].*|$)//' "$f" | grep -nE -- "$re" | head -3)
    if [ -n "$hits" ] && [ -z "${allowed["$f|$id"]:-}" ]; then
      echo "DOUBT $f [$id]: $(printf '%s' "$hits" | head -1)" >&2; fail=1
    fi
  done <<< "$patterns"
done
if [ "$fail" -eq 0 ]; then echo "OK: no doubts in ${#files[@]} Agda file(s)"; exit 0; fi
exit 1
