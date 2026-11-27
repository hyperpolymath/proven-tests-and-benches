#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
# Self-test for .proven/aspects.tsv: every aspect has a real command (none na), the cheap ones pass on
# the real tree, and each static aspect FAILS when a violation is planted in a scratch copy.
root="$(cd "$(dirname "$0")/../.." && pwd)"
. "$root/kit/lib/ptb.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
code() { "$@" >/dev/null 2>&1; echo $?; }
A="$root/kit/lib/aspect.sh"; MAP="$root/.proven/aspects.tsv"
# all 14 mapped, none na
for a in DEP SEC USA IOP SAF PER FUN VER ACC MNT PRI OBS RPR PRT; do
  ptb_eq "mapped-$a" 0 "$(awk -F'\t' -v a="$a" '$1==a && $2 !~ /^na:/ && $2 != "" {f=1} END{exit f?0:1}' "$MAP"; echo $?)"
done
# static aspects pass on the real tree
(cd "$root" && "$A" --map "$MAP" SEC USA ACC MNT PRI OBS PRT >/dev/null 2>&1); ptb_eq static-aspects-real-tree 0 "$?"
# scratch copy with one planted violation per aspect
plant() { # NAME ASPECT mutate-command
  local d="$tmp/$1"; mkdir -p "$d/benchmarks"; cp -r "$root/kit" "$d/kit"; rm -rf "$d/kit/templates"; cp -r "$root/benchmarks/kit" "$d/benchmarks/kit"; cp -r "$root/scripts" "$d/scripts"; cp -r "$root/.proven" "$d/.proven"
  (cd "$d" && eval "$3") >/dev/null 2>&1
  (cd "$d" && "$A" --map .proven/aspects.tsv "$2" >/dev/null 2>&1); echo $?
}
ptb_eq neg-SEC 1 "$(plant sec SEC "echo 'k=AKI''AABCDEFGHIJKLMNOP' >> kit/lib/e2e.sh")"
ptb_eq neg-ACC 1 "$(plant acc ACC "printf 'echo \\033[31mred\\033[0m\n' >> kit/lib/e2e.sh")"
ptb_eq neg-MNT 1 "$(plant mnt MNT "sed -i '/SPDX-License-Identifier/d' kit/lib/e2e.sh")"
ptb_eq neg-PRI 1 "$(plant pri PRI "echo 'curl example.invalid' >> kit/lib/e2e.sh")"
ptb_eq neg-OBS 1 "$(plant obs OBS "sed -i 's/NO CHECK PERFORMED/NOCHK/g' kit/lib/e2e.sh")"
ptb_eq neg-PRT 1 "$(plant prt PRT "sed -i '1s|.*|#!/bin/bash|' kit/lib/e2e.sh")"
ptb_eq neg-USA 1 "$(plant usa USA "printf '#!/usr/bin/env bash\n# SPDX-License-Identifier: MPL-2.0\nexit 0\n' > kit/lib/e2e.sh")"
ptb_done
