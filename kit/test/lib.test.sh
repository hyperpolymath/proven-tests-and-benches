#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Self-test for kit/lib/*.sh — including the negative controls.
here="$(cd "$(dirname "$0")/../lib" && pwd)"
. "$here/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ptb_ok    smoke-passes          "$here/smoke.sh" --expect '^hello' -- echo hello world
ptb_fails smoke-nonzero-fails   "$here/smoke.sh" --expect '.' -- false
ptb_fails smoke-empty-fails     "$here/smoke.sh" --expect '.' -- true
ptb_fails smoke-mismatch-fails  "$here/smoke.sh" --expect '^goodbye' -- echo hello
ptb_fails smoke-timeout-fails   "$here/smoke.sh" --timeout 1 --expect . -- sleep 5
"$here/smoke.sh" --expect . -- /no/such/bin >/dev/null 2>&1; ptb_eq smoke-missing-cmd-is-2 2 $?
ptb_ok    build-passes          "$here/build-check.sh" --artifact "$tmp/a.out" --bench-out "$tmp/b.tsv" -- sh -c "echo x > $tmp/a.out"
ptb_eq    build-bench-row       "build_seconds" "$(cut -f1 "$tmp/b.tsv")"
ptb_fails build-failing-cmd     "$here/build-check.sh" --artifact "$tmp/a.out" -- false
ptb_fails build-missing-art     "$here/build-check.sh" --artifact "$tmp/none" -- true
echo old > "$tmp/stale"; sleep 3
ptb_fails build-stale-artifact  "$here/build-check.sh" --artifact "$tmp/stale" -- true
ptb_done
