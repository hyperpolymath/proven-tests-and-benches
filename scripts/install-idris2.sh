#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Install Idris2 (chez backend) from source into $HOME/.idris2.
# Idempotent: skips the bootstrap if idris2 is already present (e.g. restored
# from a CI cache). chezscheme + GMP are always installed because the chez
# backend invokes Chez Scheme at *build* time, not just to bootstrap.

set -euxo pipefail

IDRIS2_VERSION="${IDRIS2_VERSION:-v0.7.0}"
# Callers use the numeric version; upstream release tags have a v prefix.
# Reject arbitrary refs rather than silently building an unreviewed branch.
if [[ ! "$IDRIS2_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "install-idris2: expected a release version such as 0.7.0 or v0.7.0" >&2
  exit 2
fi
IDRIS2_TAG="v${IDRIS2_VERSION#v}"
# Read-only diagnostic used by callers and regression controls before bootstrap.
if [ "${1:-}" = "--source-ref" ] && [ "$#" -eq 1 ]; then
  printf '%s\n' "$IDRIS2_TAG"
  exit 0
fi
if [ "$#" -ne 0 ]; then
  echo "install-idris2: usage: install-idris2.sh [--source-ref]" >&2
  exit 2
fi


SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# Package-manager detection (DEBT C-3): the repository's own dev container is
# Wolfi-based (apk); CI runners are Debian/Ubuntu (apt-get). With only apt-get
# here, `just deps` could not succeed inside the dev container that invokes it
# as its postCreateCommand. A box with neither manager exits 2 loudly — a skip
# is not a pass.
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update
  $SUDO apt-get install -y --no-install-recommends \
    chezscheme libgmp-dev git make gcc ca-certificates bash
elif command -v apk >/dev/null 2>&1; then
  $SUDO apk add --no-cache chez-scheme gmp-dev git make gcc musl-dev ca-certificates bash
else
  echo "install-idris2: neither apt-get nor apk found." >&2
  echo "  Install Chez Scheme, GMP headers, git, make and a C compiler, then re-run." >&2
  exit 2
fi

if [ ! -x "$HOME/.idris2/bin/idris2" ]; then
  # Scratch tree: `mktemp -d` with no template. Content_patterns/hardcoded_tmp
  # (CWE-377) flags a predictable `/tmp/<name>` because another process can
  # pre-create it and win the race; a fixed `rm -rf /tmp/Idris2` also deletes
  # whatever else happens to be sitting at that path. mktemp gives a private,
  # unpredictable, mode-0700 directory, and the trap removes it on every exit
  # path including a failed build, so a broken build no longer leaves a
  # half-cloned tree that the next run would silently build on top of.
  #
  # Deliberate behaviour change: the clone no longer survives the script. The
  # only consumer of the built compiler is $HOME/.idris2 (what the cache step
  # and the gate below use); nothing reads the scratch tree afterwards.
  SCRATCH="$(mktemp -d)"
  trap 'rm -rf "$SCRATCH"' EXIT
  git init --quiet "$SCRATCH/Idris2"
  git -C "$SCRATCH/Idris2" remote add origin https://github.com/idris-lang/Idris2
  # Fully qualify the tag: a same-named branch must not win resolution.
  git -C "$SCRATCH/Idris2" fetch --depth 1 origin "refs/tags/$IDRIS2_TAG"
  git -C "$SCRATCH/Idris2" checkout --detach FETCH_HEAD
  make -C "$SCRATCH/Idris2" bootstrap SCHEME=chezscheme
  make -C "$SCRATCH/Idris2" install
fi

"$HOME/.idris2/bin/idris2" --version
