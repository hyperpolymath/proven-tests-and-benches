#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Self-test for the REUSE gate (scripts/check-reuse.sh): proves the gate CAN
# fail, and fails for the right reason, before CI trusts its green.
#
# Each control builds a throwaway git tree, plants exactly one known defect (or
# none), and asserts BOTH the exit code AND the reason in the output. The clean
# control catches a gate that fails on everything; the reason match catches a
# gate that fails for the wrong reason.
#
# The headline firing control is `invalid-second-identifier`: a file whose
# first SPDX-License-Identifier line is valid and whose second is not. The
# previous inline gate passed it; this one must not.
#
# Needs reuse and jq on PATH. Exit codes: 0 every control behaved as planted;
# 1 at least one did not; 2 no check performed (a prerequisite is missing).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)" || { echo "FAIL: cannot reach repository root" >&2; exit 1; }
CHECK="$ROOT/scripts/check-reuse.sh"

for tool in reuse jq git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "NO CHECK PERFORMED: $tool is not installed" >&2; exit 2; }
done

WORK="$(mktemp -d)" || { echo "FAIL: mktemp" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT

passed=0
failed=0

# Strings assembled at run time so that reuse, when it lints THIS repository,
# does not read these fixture lines as this file's own licence header.
TAG_L="SPDX-License""-Identifier"
TAG_C="SPDX-File""CopyrightText"
COPY="// $TAG_C: 2026 Self Test"

# tree <name>: a fresh git repository holding the two licence texts the
# fixtures use, both of which every clean fixture actually uses.
tree() {
  local d="$WORK/$1"
  mkdir -p "$d/LICENSES"
  git -C "$d" init -q
  cp "$ROOT/LICENSES/MPL-2.0.txt" "$ROOT/LICENSES/CC-BY-SA-4.0.txt" "$d/LICENSES/"
  printf '// %s: MPL-2.0\n%s\nint main(void) { return 0; }\n' "$TAG_L" "$COPY" > "$d/code.c"
  printf '// %s: CC-BY-SA-4.0\n%s\n= Prose\n' "$TAG_L" "$COPY" > "$d/prose.adoc"
  echo "$d"
}

# stage <dir>: reuse honours git's view of the tree, so stage everything.
stage() { local dir="$1"; git -C "$dir" add -A >/dev/null; }

# expect: run a command, then assert its exit code equals $2 and its combined
# output matches the extended regex $3. $1 names the control.
expect() {
  local label="$1" want_rc="$2" want_re="$3" out rc
  shift 3
  if out="$("$@" 2>&1)"; then rc=0; else rc=$?; fi
  if [[ "$rc" -eq "$want_rc" ]] && grep -qE -- "$want_re" <<<"$out"; then
    echo "  PASS  $label (exit $rc)"
    passed=$((passed + 1))
  else
    echo "  FAIL  $label: wanted exit $want_rc matching /$want_re/, got exit $rc:"
    sed 's/^/        | /' <<<"$out"
    failed=$((failed + 1))
  fi
}

echo "check-reuse self-test"

# --- Silence: a compliant tree passes ------------------------------------
d="$(tree clean)"; stage "$d"
expect "clean tree passes" 0 '^OK: REUSE compliant' "$CHECK" "$d"

# --- Firing: the hole this gate was written to close ---------------------
d="$(tree invalid-second)"
printf '// %s: MPL-2.0 and CC-BY-SA-4.0\n// %s: MPL-2.0 (code) and CC-BY-SA-4.0 (prose)\n%s\n= Mixed\n' \
  "$TAG_L" "$TAG_L" "$COPY" > "$d/mixed.adoc"
stage "$d"
expect "invalid second identifier fails, named" 1 \
  'invalid SPDX expression in mixed\.adoc: MPL-2\.0 \(code\)' "$CHECK" "$d"

d="$(tree invalid-only)"
printf '// %s: MPL-2.0 (code)\n%s\n= Only\n' "$TAG_L" "$COPY" > "$d/only.adoc"
stage "$d"
expect "sole invalid identifier fails (no licence)" 1 \
  'missing_licensing_info: (.*/)?only\.adoc' "$CHECK" "$d"

d="$(tree no-copyright)"
printf '// %s: CC-BY-SA-4.0\n= No copyright\n' "$TAG_L" > "$d/bare.adoc"
stage "$d"
expect "missing copyright fails, named" 1 'missing_copyright_info: (.*/)?bare\.adoc' "$CHECK" "$d"

d="$(tree unused)"
cp "$ROOT/LICENSES/MPL-2.0.txt" "$d/LICENSES/Apache-2.0.txt"
stage "$d"
expect "unused licence text fails (no tolerance left)" 1 'unused_licenses: Apache-2\.0' "$CHECK" "$d"

d="$(tree missing-text)"
printf '// %s: Apache-2.0\n%s\nint f(void);\n' "$TAG_L" "$COPY" > "$d/apache.c"
stage "$d"
expect "licence used without its text fails" 1 'missing_licenses: Apache-2\.0' "$CHECK" "$d"

# --- Fail-closed: no judgement is never a pass ---------------------------
expect "nonexistent directory is no check" 2 'NO CHECK PERFORMED: directory not found' \
  "$CHECK" "$WORK/does-not-exist"

# A PATH holding only what the gate needs before it looks for reuse (bash for
# its shebang, jq), so the control holds wherever reuse happens to be installed.
mkdir -p "$WORK/bin"
ln -s "$(command -v bash)" "$WORK/bin/bash"
ln -s "$(command -v jq)" "$WORK/bin/jq"
expect "reuse missing from PATH is no check" 2 'NO CHECK PERFORMED: reuse is not installed' \
  env PATH="$WORK/bin" "$CHECK" "$WORK/clean"

printf '{ not json' > "$WORK/malformed.json"
expect "malformed report is no check" 2 'NO CHECK PERFORMED: report is not valid' \
  "$CHECK" --json "$WORK/malformed.json"

printf '{"summary":{"compliant":true}}\n' > "$WORK/shape.json"
expect "unknown report shape is no check" 2 'NO CHECK PERFORMED: report is not valid' \
  "$CHECK" --json "$WORK/shape.json"

# Inner shapes the checks read. Each report claims compliant=true, so a gate
# that skipped the odd value would print OK: these must be exit 2 instead.
printf '{"non_compliant":{"missing_licenses":"Apache-2.0"},"files":[],"summary":{"compliant":true}}\n' > "$WORK/string-category.json"
expect "non-array category is no check, not a pass" 2 'NO CHECK PERFORMED: report is not valid' \
  "$CHECK" --json "$WORK/string-category.json"

printf '{"non_compliant":{},"files":[{"path":"a.adoc","spdx_expressions":[{"value":"MPL-2.0 (code)","is_valid":"false"}]}],"summary":{"compliant":true}}\n' > "$WORK/string-valid.json"
expect "non-boolean is_valid is no check, not a pass" 2 'NO CHECK PERFORMED: report is not valid' \
  "$CHECK" --json "$WORK/string-valid.json"

# reuse 6.3.0 always emits spdx_expressions as an array, even for a file with
# no licence at all, so a null or missing value is an unknown shape, not "none".
printf '{"non_compliant":{},"files":[{"path":"a.adoc","spdx_expressions":null}],"summary":{"compliant":true}}\n' > "$WORK/null-expressions.json"
expect "null spdx_expressions is no check, not a pass" 2 'NO CHECK PERFORMED: report is not valid' \
  "$CHECK" --json "$WORK/null-expressions.json"

# A future reuse category this gate does not know: compliant=false with every
# known category empty must still fail (the catch-all).
printf '{"non_compliant":{},"files":[],"summary":{"compliant":false,"files_total":1}}\n' > "$WORK/unknown-reason.json"
expect "non-compliance for an unnamed reason still fails" 1 'for a reason this gate does not name' \
  "$CHECK" --json "$WORK/unknown-reason.json"

expect "wrong argument count is no check" 2 'NO CHECK PERFORMED: usage' "$CHECK" a b

echo "check-reuse self-test: $passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
