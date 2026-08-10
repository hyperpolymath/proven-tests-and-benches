#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# `gh actions-lock` restamps "# This workflow is managed by gh actions-lock."
# onto LINE 1 of every workflow it touches, displacing the SPDX header — and
# the estate licence linter greps line 1 only, so every regen breaks the
# governance workflow-lint gate (hit twice on 2026-08-10 alone). Run this after
# every `gh actions-lock` invocation; it is idempotent.
set -euo pipefail
BANNER="# This workflow is managed by gh actions-lock."
for f in .github/workflows/*.yml; do
  if [ "$(head -1 "$f")" = "$BANNER" ]; then
    python3 - "$f" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); lines = p.read_text().split("\n")
banner = lines.pop(0)
# drop duplicate banners already below (regen can stack them)
lines = [l for l in lines if l != banner]
idx = 0
while idx < len(lines) and lines[idx].startswith("# SPDX"):
    idx += 1
lines.insert(idx, banner)
p.write_text("\n".join(lines))
print(f"moved banner below SPDX in {sys.argv[1]}")
PY
  fi
done
