#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for contract, typesafe, proofreg, aspect libs, negative controls included.
here="$(cd "$(dirname "$0")/../lib" && pwd)"
. "$here/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
# CTR
ptb_eq ctr-ok            0 "$(code "$here/contract.sh" --require '^hello' --forbid 'ERROR' -- echo hello world)"
ptb_eq ctr-require-miss  1 "$(code "$here/contract.sh" --require '^nope' -- echo hello)"
ptb_eq ctr-forbid-hit    1 "$(code "$here/contract.sh" --forbid 'hello' -- echo hello)"
ptb_eq ctr-cmd-fails     1 "$(code "$here/contract.sh" --require . -- false)"
ptb_eq ctr-silent-2      2 "$(code "$here/contract.sh" --require . -- true)"
ptb_eq ctr-no-invar-2    2 "$(code "$here/contract.sh" -- echo hi)"
ptb_eq ctr-no-cmd-2      2 "$(code "$here/contract.sh" --require . -- /no/such/bin)"
ptb_eq ctr-usage-2       2 "$(code "$here/contract.sh")"
# TSF
mkdir "$tmp/src"; echo 'ok = 1' > "$tmp/src/a.idr"; echo 'x = believe_me y' > "$tmp/src/b.idr"
ptb_eq tsf-clean         0 "$(code "$here/typesafe.sh" --forbid 'believe_me' --in "$tmp/src/a.idr" -- true)"
ptb_eq tsf-hatch-1       1 "$(code "$here/typesafe.sh" --forbid 'believe_me' --in "$tmp/src" -- true)"
ptb_eq tsf-check-fails-1 1 "$(code "$here/typesafe.sh" --forbid 'believe_me' --in "$tmp/src/a.idr" -- false)"
ptb_eq tsf-no-path-2     2 "$(code "$here/typesafe.sh" --forbid 'x' --in "$tmp/none" -- true)"
ptb_eq tsf-no-cmd-2      2 "$(code "$here/typesafe.sh" --forbid 'x' --in "$tmp/src" -- /no/such/bin)"
ptb_eq tsf-usage-2       2 "$(code "$here/typesafe.sh")"
# PRF
printf '# claims\nthm_a\nthm_b\n' > "$tmp/claims"; : > "$tmp/noclaims"; echo '# only' > "$tmp/comment"
ptb_eq prf-all           0 "$(code "$here/proofreg.sh" --claims "$tmp/claims" -- printf 'thm_a\nthm_b\nthm_c\n')"
ptb_eq prf-vanished-1    1 "$(code "$here/proofreg.sh" --claims "$tmp/claims" -- printf 'thm_a\n')"
ptb_eq prf-prefix-not-1  1 "$(code "$here/proofreg.sh" --claims "$tmp/claims" -- printf 'thm_a\nthm_bb\n')"
ptb_eq prf-prover-fails  1 "$(code "$here/proofreg.sh" --claims "$tmp/claims" -- false)"
ptb_eq prf-prover-exit-1 1 "$(code "$here/proofreg.sh" --claims "$tmp/claims" -- bash -c 'printf "thm_a\nthm_b\n"; exit 1')"
ptb_eq prf-empty-2       2 "$(code "$here/proofreg.sh" --claims "$tmp/noclaims" -- true)"
ptb_eq prf-comment-only  2 "$(code "$here/proofreg.sh" --claims "$tmp/comment" -- true)"
ptb_eq prf-no-file-2     2 "$(code "$here/proofreg.sh" --claims "$tmp/none" -- true)"
ptb_eq prf-usage-2       2 "$(code "$here/proofreg.sh")"
# ASPECT
printf 'XXX\ttrue\nSEC\ttrue\nPER\tfalse\nPRT\tna:linux-only tool\nPRI\tna:\nFUN\ttrue\n' > "$tmp/map"
ptb_eq asp-pass          0 "$(code "$here/aspect.sh" --map "$tmp/map" SEC FUN)"
ptb_eq asp-na-ok         0 "$(code "$here/aspect.sh" --map "$tmp/map" PRT)"
ptb_eq asp-fail-1        1 "$(code "$here/aspect.sh" --map "$tmp/map" SEC PER)"
ptb_eq asp-unmapped-2    2 "$(code "$here/aspect.sh" --map "$tmp/map" DEP)"
ptb_eq asp-unknown-2     2 "$(code "$here/aspect.sh" --map "$tmp/map" XXX)"
ptb_eq asp-na-noreason-2 2 "$(code "$here/aspect.sh" --map "$tmp/map" PRI)"
ptb_eq asp-no-map-2      2 "$(code "$here/aspect.sh" --map "$tmp/none" SEC)"
ptb_eq asp-usage-2       2 "$(code "$here/aspect.sh")"
ptb_done
