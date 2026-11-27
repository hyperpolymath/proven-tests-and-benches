#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# dogfood.sh — DOG-01/02/06/07/08: the estate checking its own checks.
#   nonempty-output -- CMD...            DOG-01: CMD prints something that is not "[]"
#   findings-have-location FILE          DOG-02: JSON array, every item has non-null file and line
#   no-placeholders PATH...              DOG-06: no {{OWNER}} / [YOUR-REPO-NAME] left in PATHs
#   current REF COPY                     DOG-07: COPY is byte-identical to the template REF
#   field-contract FILE FIELD...         DOG-08: JSON FILE has every FIELD (jq path, e.g. .a.b)
# Exit: 0 pass; 1 violation; 2 no check performed (bad usage, missing input, jq absent).
set -u
sub="${1:-}"; [[ $# -gt 0 ]] && shift
need_jq() { command -v jq >/dev/null || { echo "NO CHECK PERFORMED: jq absent" >&2; exit 2; }; }
case "$sub" in
  nonempty-output)
    [[ "${1:-}" == "--" ]] && shift
    [[ $# -gt 0 ]] || { echo "NO CHECK PERFORMED: no command" >&2; exit 2; }
    out="$("$@" 2>/dev/null)"; rc=$?
    stripped="${out//[[:space:]]/}"
    [[ "$rc" -eq 127 ]] && { echo "NO CHECK PERFORMED: command not found" >&2; exit 2; }
    [[ -n "$stripped" && "$stripped" != "[]" && "$stripped" != "{}" ]] || { echo "VIOLATION: empty output (silent no-op)" >&2; exit 1; }
    echo "OK: output non-empty" ;;
  findings-have-location)
    need_jq; file="${1:-}"
    [[ -r "$file" ]] || { echo "NO CHECK PERFORMED: $file unreadable" >&2; exit 2; }
    jq -e 'type=="array"' "$file" >/dev/null 2>&1 || { echo "VIOLATION: $file is not a JSON array" >&2; exit 1; }
    bad="$(jq '[.[] | select((.file // null)==null or (.line // null)==null)] | length' "$file")"
    [[ "$bad" == 0 ]] || { echo "VIOLATION: $bad finding(s) without file/line" >&2; exit 1; }
    echo "OK: all findings located" ;;
  no-placeholders)
    [[ $# -gt 0 ]] || { echo "NO CHECK PERFORMED: no paths" >&2; exit 2; }
    for p in "$@"; do [[ -e "$p" ]] || { echo "NO CHECK PERFORMED: $p missing" >&2; exit 2; }; done
    if grep -rnE '\{\{[A-Z_]+\}\}|\[YOUR-[A-Z-]+\]' -- "$@" >&2; then echo "VIOLATION: template placeholder left" >&2; exit 1; fi
    echo "OK: no placeholders" ;;
  current)
    ref="${1:-}"; copy="${2:-}"
    [[ -r "$ref" && -r "$copy" ]] || { echo "NO CHECK PERFORMED: ref or copy unreadable" >&2; exit 2; }
    cmp -s "$ref" "$copy" || { echo "VIOLATION: $copy differs from template $ref" >&2; exit 1; }
    echo "OK: copy current" ;;
  field-contract)
    need_jq; file="${1:-}"; [[ $# -gt 0 ]] && shift
    [[ -r "$file" && $# -gt 0 ]] || { echo "NO CHECK PERFORMED: need FILE and FIELD..." >&2; exit 2; }
    miss=0
    for f in "$@"; do jq -e "$f != null" "$file" >/dev/null 2>&1 || { echo "VIOLATION: field $f missing in $file" >&2; miss=1; }; done
    [[ "$miss" -eq 0 ]] || exit 1
    echo "OK: all fields present" ;;
  *) echo "NO CHECK PERFORMED: usage: unknown subcommand '$sub'" >&2; exit 2 ;;
esac
