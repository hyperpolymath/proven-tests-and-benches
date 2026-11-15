#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
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
# The C preprocessor normally looks beside the consumer before -I paths:
# a local stale header must not cause the supplied public header to be ignored.
mkdir -p "$temp/public" "$temp/adjacent"
cp "$temp/fixture.h" "$temp/public/fixture.h"
cp "$temp/fixture.h" "$temp/adjacent/fixture.h"
cp "$temp/consumer.c" "$temp/adjacent/consumer.c"
sed -i 's/CONTRACT_MAGIC 7/CONTRACT_MAGIC 8/' "$temp/public/fixture.h"
expect 1 'firing: supplied header beats stale adjacent header' \
  bash "$runner" "$temp/public/fixture.h" "$temp/adjacent/consumer.c" "$temp/fixture.a"

# A native archive may need another archive. One-pass linkers require
# dependencies to follow the subject, never precede it.
cat > "$temp/helper.c" <<'EOF'
int helper_magic(void) { return 7; }
EOF
cat > "$temp/needs_helper.c" <<'EOF'
#include "fixture.h"
extern int helper_magic(void);
int contract_magic(void) { return helper_magic(); }
EOF
cc -std=c11 -Wall -Wextra -Werror -c "$temp/helper.c" -o "$temp/helper.o"
cc -std=c11 -Wall -Wextra -Werror -I"$temp" -c "$temp/needs_helper.c" -o "$temp/needs_helper.o"
ar rcs "$temp/helper.a" "$temp/helper.o"
ar rcs "$temp/needs-helper.a" "$temp/needs_helper.o"
expect 1 'firing: omitted required static dependency' \
  bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/needs-helper.a"
expect 0 'silence: dependency after native subject archive' \
  env C_ABI_LDLIBS="$temp/helper.a" bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/needs-helper.a"

# A contract consumer that hangs must terminate promptly with a failure,
# not leave a required CI job waiting indefinitely.
cat > "$temp/hanging.c" <<'EOF'
#include "fixture.h"
int main(void) {
  volatile unsigned long counter = 0;
  for (;;) { counter++; }
}
EOF
expect 1 'firing: bounded non-terminating ABI client' \
  env C_ABI_TIMEOUT=1s bash "$runner" "$temp/fixture.h" "$temp/hanging.c" "$temp/fixture.a"
expect 2 'void: invalid runner timeout' \
  env C_ABI_TIMEOUT=invalid bash "$runner" "$temp/fixture.h" "$temp/consumer.c" "$temp/fixture.a"
# Exit 125, 126 and 127 are legal *executed* client failures. They must
# never be reclassified as NOT RUN just because GNU timeout reserves them.
for code in 125 126 127; do
  cat > "$temp/reserved-exit.c" <<EOF
#include "fixture.h"
int main(void) { return $code; }
EOF
  expect 1 "firing: executed subject returned reserved exit $code" \
    bash "$runner" "$temp/fixture.h" "$temp/reserved-exit.c" "$temp/fixture.a"
  grep -Fq "FAIL: executed ABI consumer exited $code" "$temp/out" || {
    echo "FAIL: execution handshake lost subject exit $code" >&2; exit 1;
  }
done
# Conversely, a missing executable must be reported as no-run by the same
# launcher, not confused with an executed client's deliberate exit 127.
cc -std=c11 -Wall -Wextra -Werror "$root/launcher.c" -o "$temp/launcher"
expect 2 'void: launcher could not exec missing consumer binary' \
  "$temp/launcher" "$temp/nonexistent-executable"
grep -Fq 'NOT RUN: child exec failed' "$temp/out" || {
  echo 'FAIL: missing executable not classified as NOT RUN' >&2; exit 1;
}
echo 'ok: genuine compile/link/run, reserved exits 125-127, no-exec, header, dependency, deadline and unavailable controls'
