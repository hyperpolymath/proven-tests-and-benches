#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
# Reusable executed C ABI contract test (category 2 P2P / 12 contract / 18 drift).
# This is a harness, not a claim that arbitrary client assertions are sound.
# Return 0: executed and passed; 1: executed and failed; 2: NOT RUN / invalid setup.
set -euo pipefail
void() { printf 'NOT RUN: %s\n' "$*" >&2; exit 2; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ $# == 3 ]] || void 'usage: run.sh <header.h> <consumer.c> <static-library.a>'
header=$1
client=$2
library=$3
for source in "$header" "$client" "$library"; do
  [[ -f "$source" && -r "$source" && -s "$source" ]] || void "missing/empty/unreadable input: $source"
done
compiler=${CC:-cc}
# CC may be "zig cc" or a single compiler executable. Split into argv,
# never evaluate a shell command or interpolate compiler-supplied syntax.
read -r -a cc_argv <<< "$compiler"
[[ ${#cc_argv[@]} -gt 0 ]] || void 'empty C compiler command'
command -v "${cc_argv[0]}" >/dev/null 2>&1 || void "C compiler not available: ${cc_argv[0]}"
temp=$(mktemp -d) || void 'cannot allocate isolated compile workspace'
trap 'rm -rf "$temp"' EXIT
if ! "${cc_argv[@]}" -std=c11 -Wall -Wextra -Werror -I"$(dirname "$header")" \
     "$client" "$library" -o "$temp/consumer"; then
  fail 'C ABI consumer failed to compile/link'
fi
[[ -x "$temp/consumer" ]] || void 'compiler claimed success but emitted no executable'
if ! "$temp/consumer"; then
  fail 'executed C ABI consumer rejected the contract'
fi
printf 'PASS: compiled, linked and executed C ABI consumer: %s\n' "$client"
