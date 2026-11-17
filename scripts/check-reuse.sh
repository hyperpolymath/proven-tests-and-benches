#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# REUSE compliance gate. One implementation, shared by `ci.yml` and `just lint`.
#
# WHY THIS EXISTS
# ---------------
# The REUSE step in ci.yml used to be an inline heredoc that failed only on
# non-empty keys under the JSON `non_compliant` object. reuse 6.3.0 records an
# unparseable `SPDX-License-Identifier` value nowhere in `non_compliant`: it
# appears only as `files[].spdx_expressions[].is_valid == false`, with
# `summary.compliant == false`. A file whose first identifier line was valid
# and whose second was not (for example `MPL-2.0 (code) and CC-BY-SA-4.0
# (prose)`) therefore passed the gate while `reuse lint` itself reported the
# project non-compliant. A gate that cannot fail on that input is a gate that
# reads green when it should not (AGENTS.adoc: "Do not write a gate that cannot
# fail"). Reproduced 2026-11-17 with reuse 6.3.0.
#
# This script fails on every route that reuse marks non-compliant:
#   1. any non-empty `non_compliant` category (named in the output);
#   2. any SPDX expression that reuse could not parse (file and value named);
#   3. `summary.compliant == false` for a reason neither 1 nor 2 names: a
#      catch-all, so a category added by a future reuse release fails closed
#      instead of passing silently.
# There are no tolerances. The one the inline step carried (an unused
# AGPL-3.0-or-later licence text, DEBT L-1) was resolved on 2026-08-29 when the
# text was removed, so it had become an exemption for a file that no longer
# exists.
#
# Usage:
#   scripts/check-reuse.sh [DIR]          run `reuse lint --json` on DIR
#                                         (default: the repository root)
#   scripts/check-reuse.sh --json FILE    judge a saved `reuse lint --json`
#                                         report (used by the self-test)
#
# Exit codes: 0 = compliant, 1 = non-compliant (each reason named),
#             2 = no check performed (reuse/jq missing, reuse crashed, or the
#                 report is unreadable or not the shape this gate understands).

set -uo pipefail

no_check() { echo "NO CHECK PERFORMED: $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || no_check "jq is not installed"

report=""
cleanup=""
trap '[ -n "$cleanup" ] && rm -f "$cleanup"' EXIT

if [ "${1:-}" = "--json" ]; then
  [ $# -eq 2 ] || no_check "usage: $0 --json FILE"
  report="$2"
  [ -f "$report" ] || no_check "report file not found: $report"
else
  [ $# -le 1 ] || no_check "usage: $0 [DIR] | --json FILE"
  dir="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
  [ -d "$dir" ] || no_check "directory not found: $dir"
  command -v reuse >/dev/null 2>&1 || no_check "reuse is not installed (pipx install reuse)"
  report="$(mktemp)" || no_check "mktemp failed"
  cleanup="$report"
  # reuse lint exits 0 (compliant) or 1 (non-compliant); both mean it ran.
  # Anything else means it did not judge the tree, and that is not a pass.
  reuse --root "$dir" lint --json > "$report"
  rc=$?
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
    no_check "reuse lint exited $rc on $dir"
  fi
fi

# The report must be the shape this gate was written against; an unknown shape
# is exit 2, never an implicit pass.
jq -e '
  (.non_compliant | type) == "object"
  and (.files | type) == "array"
  and (.summary.compliant | type) == "boolean"
' "$report" >/dev/null 2>&1 \
  || no_check "report is not valid reuse lint JSON (needs non_compliant, files, summary.compliant): $report"

failures="$(jq -r '
  [ .non_compliant | to_entries[]
    | select((.value | type) == "array" and (.value | length) > 0)
    | "\(.key): \(.value | map(if type == "object" then (.license // .path // tostring) else tostring end) | join(", "))" ]
  + [ .files[] | .path as $p | (.spdx_expressions // [])[]
      | select(.is_valid == false)
      | "invalid SPDX expression in \($p): \(.value)" ]
  | .[]
' "$report")" || no_check "jq could not evaluate the report"

compliant="$(jq -r '.summary.compliant' "$report")"
files="$(jq -r '.summary.files_total // "?"' "$report")"
tool="$(jq -r '.reuse_tool_version // "unknown"' "$report")"

if [ -n "$failures" ]; then
  echo "FAIL: REUSE non-compliance (reuse $tool, $files files):"
  while IFS= read -r line; do echo "  - $line"; done <<<"$failures"
  exit 1
fi

if [ "$compliant" != "true" ]; then
  echo "FAIL: reuse reports the project non-compliant (reuse $tool, $files files) for a reason this gate does not name."
  echo "  Run \`reuse lint\` for details, then teach scripts/check-reuse.sh the new category."
  exit 1
fi

echo "OK: REUSE compliant across $files files (reuse $tool; no tolerances)"
exit 0
