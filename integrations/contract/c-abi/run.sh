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
# Dependency tracing checks that the EXACT supplied public header was
# included, without changing the consumer's original preprocessing order.
# Forced -include is not correct for macro-configurable C public headers.
compile_args=(-std=c11 -Wall -Wextra "-I$(dirname "$header")"
              -MD -MF "$temp/dependencies.d" -MT abi-consumer
              "$client" "$library")
case ${C_ABI_STRICT_WARNINGS:-no} in
  yes) compile_args+=(-Werror) ;;
  no) ;;
  *) void 'C_ABI_STRICT_WARNINGS must be yes or no' ;;
esac
# Bash 4.3 with nounset may reject expansion of an empty array; only append
# dependent libraries when there are actually arguments to append.
if [[ -n ${C_ABI_LDLIBS:-} ]]; then
  compile_args+=("${link_args[@]}")
fi
compile_args+=(-o "$temp/consumer")
if "${cc_argv[@]}" "${compile_args[@]}"; then
  :
else
  compile_rc=$?
  case $compile_rc in
    126|127) void "C compiler could not launch (exit $compile_rc)" ;;
    12[89]|1[3-9][0-9]|2[0-5][0-5]) void "C compiler aborted or signaled (exit $compile_rc)" ;;
    *) fail "C ABI consumer failed to compile/link (compiler exit $compile_rc)" ;;
  esac
fi
[[ -s "$temp/dependencies.d" ]] || void 'compiler produced no C include dependency evidence'
# GCC and Clang -MD emit a make dependency file. We canonicalise its tokens
# before comparing; unsupported whitespace-containing paths fail closed.
header_canonical=$(realpath -e -- "$header") || void 'cannot canonicalise public header'
case "$header_canonical" in
  *[[:space:]]*) void 'ABI header path with whitespace is not yet supported by dependency reader' ;;
  *) : ;; # Known valid path requires no further transformation.
esac
deps=$(sed ':a;N;$!ba;s/\\\n/ /g' "$temp/dependencies.d")
deps=${deps#*:}
header_seen=0
# Preserve splitting of make tokens, but never expand their glob characters.
case $- in *f*) restore_globbing=no ;; *) restore_globbing=yes ;; esac
set -f
for dependency in $deps; do
  [[ -f "$dependency" ]] || continue
  candidate=$(realpath -e -- "$dependency") || continue
  if [[ $candidate == "$header_canonical" ]]; then header_seen=1; break; fi
done
if [[ $restore_globbing == yes ]]; then set +f; fi
[[ $header_seen == 1 ]] || fail 'client did not include the supplied public header; stale/shadow header or missing include'
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
# The launcher stays alive on SIGTERM until it reaps the consumer, so timeout
# can still escalate if needed; the launcher kills and reaps its child first.
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
