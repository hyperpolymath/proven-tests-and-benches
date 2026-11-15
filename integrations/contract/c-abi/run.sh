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
# CC may be "zig cc" or a single compiler executable. Split into argv;
# no eval and no execution of input as shell source.
read -r -a cc_argv <<< "$compiler"
[[ ${#cc_argv[@]} -gt 0 ]] || void 'empty C compiler command'
command -v "${cc_argv[0]}" >/dev/null 2>&1 || void "C compiler not available: ${cc_argv[0]}"
command -v timeout >/dev/null 2>&1 || void 'coreutils timeout unavailable'
# A dependent static archive must appear AFTER the subject library for
# conventional one-pass linkers. Literal whitespace-separated argv, not eval.
link_args=()
if [[ -n ${C_ABI_LDLIBS:-} ]]; then
  read -r -a link_args <<< "$C_ABI_LDLIBS"
fi
duration=${C_ABI_TIMEOUT:-20s}
[[ $duration =~ ^([1-9][0-9]*)(s|m)$ ]] || void 'C_ABI_TIMEOUT must be positive seconds/minutes'
temp=$(mktemp -d) || void 'cannot allocate isolated compile workspace'
trap 'rm -rf "$temp"' EXIT
# -include forces the EXACT supplied header to be consumed BEFORE client-local
# quoted includes. A stale adjacent header cannot silently override the
# public contract. The independent client must still assert meaningful facts.
if ! "${cc_argv[@]}" -std=c11 -Wall -Wextra -Werror -I"$(dirname "$header")" \
     -include "$header" "$client" "$library" "${link_args[@]}" -o "$temp/consumer"; then
  fail 'C ABI consumer failed to compile/link'
fi
[[ -x "$temp/consumer" ]] || void 'compiler claimed success but emitted no executable'
# A separate POSIX launcher observes exec() through a close-on-exec pipe.
# It normalises a genuinely executed child's exit 125/126/127 to failure,
# reserving status 2 only for a child that never started. Without a handshake,
# GNU timeout's 125/126/127 statuses are indistinguishable from user exits.
launcher_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/launcher.c"
[[ -s "$launcher_source" ]] || void 'POSIX execution-handshake source missing'
if ! "${cc_argv[@]}" -std=c11 -Wall -Wextra -Werror \
    "$launcher_source" -o "$temp/launcher"; then
  void 'could not compile execution-handshake launcher'
fi
[[ -x "$temp/launcher" ]] || void 'execution-handshake launcher unavailable'
# Timeout's 124/137 mean a non-terminating executable. 125/126/127 now
# mean coreutils could not invoke the launcher, not the subject's status.
if timeout --kill-after=2s "$duration" "$temp/launcher" "$temp/consumer"; then
  :
else
  rc=$?
  case $rc in
    2|125|126|127) void "compiled ABI client could not launch or observe an execution result (exit $rc)" ;;
    124|137) fail "ABI client failed to terminate within $duration (exit $rc)" ;;
    *) fail "executed C ABI consumer rejected contract (exit $rc)" ;;
  esac
fi
printf 'PASS: compiled, linked and executed C ABI consumer: %s\n' "$client"
