#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Silence, firing and void controls for the generic, non-proof C ABI harness.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
runner=$root/run.sh
command -v cc >/dev/null 2>&1 || { echo 'NOT RUN: cc missing' >&2; exit 2; }
command -v ar >/dev/null 2>&1 || { echo 'NOT RUN: ar missing' >&2; exit 2; }
temp=$(mktemp -d) || exit 2
trap 'rm -rf "$temp"' EXIT
cat > "$temp/fixture.h" <<'EOF'
#ifndef FIXTURE_H
#define FIXTURE_H
#define CONTRACT_MAGIC 7
int contract_magic(void);
#endif
EOF
cat > "$temp/implementation.c" <<'EOF'
#include "fixture.h"
int contract_magic(void) { return 7; }
EOF
cat > "$temp/consumer.c" <<'EOF'
#include "fixture.h"
_Static_assert(CONTRACT_MAGIC == 7, "header contract drift");
int main(void) { return contract_magic() == CONTRACT_MAGIC ? 0 : 1; }
EOF
cc -std=c11 -Wall -Wextra -Werror -I"$temp" -c "$temp/implementation.c" -o "$temp/implementation.o"
ar rcs "$temp/fixture.a" "$temp/implementation.o"
bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/fixture.a" > "$temp/output"
grep -Fq 'PASS: compiled, linked and executed' "$temp/output"
echo 'ok: silence control compiles, links and executes'
expect() {
  local want=$1 label=$2
  shift 2
  local got=0
  "$@" > "$temp/out" 2>&1 || got=$?
  [[ "$got" == "$want" ]] || {
    printf 'FAIL: %s returned %s, expected %s\n' "$label" "$got" "$want" >&2
    cat "$temp/out" >&2
    exit 1
  }
  echo "ok: $label (exit $want)"
}
# A source-level mutation must be detected at compile time, not merely grep.
sed -i 's/CONTRACT_MAGIC 7/CONTRACT_MAGIC 8/' "$temp/fixture.h"
expect 1 'firing: header constant mutation' bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/fixture.a"
sed -i 's/CONTRACT_MAGIC 8/CONTRACT_MAGIC 7/' "$temp/fixture.h"
# A separate firing control reaches the executable, then fails its assertion.
sed -i 's/return contract_magic() == CONTRACT_MAGIC ? 0 : 1;/return contract_magic() == 999 ? 0 : 1;/' "$temp/consumer.c"
expect 1 'firing: runtime contract violation' bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/fixture.a"
sed -i 's/contract_magic() == 999/contract_magic() == CONTRACT_MAGIC/' "$temp/consumer.c"
# A syntactically bad client must also make the gate red.
printf '\nnot a valid C declaration\n' >> "$temp/consumer.c"
expect 1 'firing: client compile defect' bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/fixture.a"
sed -i '$d' "$temp/consumer.c"
# Missing tool and missing subject must NOT be mistaken for test failures.
expect 2 'void: missing library' bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/absent.a"
expect 2 'void: missing compiler' env CC=nonexistent_c_compiler bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/fixture.a"
expect 2 'void: missing consumer' bash "$runner" "$temp/fixture.h" "$temp/absent.c" "$temp/fixture.a"
expect 2 'void: missing arguments' bash "$runner"
echo 'ok: one silence, three firing and four void controls'
