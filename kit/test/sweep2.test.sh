#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for the sweep 2 kit libs (regression, drift, reflexive, e2e), negative controls included.
here="$(cd "$(dirname "$0")/../lib" && pwd)"
. "$here/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
echo hello > "$tmp/g"; : > "$tmp/empty"; echo bye > "$tmp/other"
# REG
ptb_eq regression-match        0 "$(code "$here/regression.sh" --golden "$tmp/g" -- echo hello)"
ptb_eq regression-differs-is-1 1 "$(code "$here/regression.sh" --golden "$tmp/g" -- echo changed)"
ptb_eq regression-cmd-fails-1  1 "$(code "$here/regression.sh" --golden "$tmp/g" -- false)"
ptb_eq regression-no-golden-2  2 "$(code "$here/regression.sh" --golden "$tmp/none" -- echo hello)"
ptb_eq regression-empty-gold-2 2 "$(code "$here/regression.sh" --golden "$tmp/empty" -- echo hello)"
ptb_eq regression-no-cmd-2     2 "$(code "$here/regression.sh" --golden "$tmp/g" -- /no/such/bin)"
ptb_eq regression-usage-2      2 "$(code "$here/regression.sh")"
# CDF
ptb_eq drift-agrees            0 "$(code "$here/drift.sh" --generated-by echo hello --committed "$tmp/g")"
ptb_eq drift-stale-is-1        1 "$(code "$here/drift.sh" --generated-by echo hello --committed "$tmp/other")"
ptb_eq drift-gen-fails-2       2 "$(code "$here/drift.sh" --generated-by false --committed "$tmp/g")"
ptb_eq drift-gen-silent-2      2 "$(code "$here/drift.sh" --generated-by true --committed "$tmp/g")"
ptb_eq drift-no-committed-2    2 "$(code "$here/drift.sh" --generated-by echo hello --committed "$tmp/none")"
ptb_eq drift-usage-2           2 "$(code "$here/drift.sh")"
# REF
ptb_eq reflexive-det           0 "$(code "$here/reflexive.sh" -- echo same)"
ptb_eq reflexive-nondet-1      1 "$(code "$here/reflexive.sh" -- bash -c 'echo $RANDOM$RANDOM$RANDOM')"
ptb_eq reflexive-cmd-fails-2   2 "$(code "$here/reflexive.sh" -- false)"
ptb_eq reflexive-idem-ok       0 "$(echo ' a ' | code "$here/reflexive.sh" --idempotent -- tr -d ' ')"
ptb_eq reflexive-notidem-1     1 "$(echo abc | code "$here/reflexive.sh" --idempotent -- sed 's/$/x/')"
ptb_eq reflexive-no-cmd-2      2 "$(code "$here/reflexive.sh" -- /no/such/bin)"
ptb_eq reflexive-usage-2       2 "$(code "$here/reflexive.sh")"
# E2E
echo input > "$tmp/in"
ptb_eq e2e-pass                0 "$(code "$here/e2e.sh" --expect '^hello' -- echo hello)"
ptb_eq e2e-stdin               0 "$(code "$here/e2e.sh" --stdin "$tmp/in" --expect '^input' -- cat)"
ptb_eq e2e-expected-nonzero    0 "$(code "$here/e2e.sh" --expect-exit 3 --expect . -- bash -c 'echo x; exit 3')"
ptb_eq e2e-wrong-exit-1        1 "$(code "$here/e2e.sh" --expect . -- bash -c 'echo x; exit 3')"
ptb_eq e2e-empty-stdout-1      1 "$(code "$here/e2e.sh" --expect . -- true)"
ptb_eq e2e-mismatch-1          1 "$(code "$here/e2e.sh" --expect '^nope' -- echo hello)"
ptb_eq e2e-timeout-1           1 "$(code "$here/e2e.sh" --timeout 1 --expect . -- sleep 5)"
ptb_eq e2e-no-cmd-2            2 "$(code "$here/e2e.sh" --expect . -- /no/such/bin)"
ptb_eq e2e-bad-stdin-2         2 "$(code "$here/e2e.sh" --stdin "$tmp/none" --expect . -- cat)"
ptb_eq e2e-bad-exit-arg-2      2 "$(code "$here/e2e.sh" --expect-exit x --expect . -- echo a)"
ptb_eq e2e-usage-2             2 "$(code "$here/e2e.sh")"
ptb_done
