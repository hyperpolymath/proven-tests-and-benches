#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Install Idris2 (chez backend) from source into $HOME/.idris2.
# Idempotent: skips the bootstrap if idris2 is already present (e.g. restored
# from a CI cache). chezscheme + GMP are always installed because the chez
# backend invokes Chez Scheme at *build* time, not just to bootstrap.

set -euxo pipefail

IDRIS2_VERSION="${IDRIS2_VERSION:-v0.7.0}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  chezscheme libgmp-dev git make gcc ca-certificates bash

if [ ! -x "$HOME/.idris2/bin/idris2" ]; then
  rm -rf /tmp/Idris2
  git clone --depth 1 --branch "$IDRIS2_VERSION" https://github.com/idris-lang/Idris2 /tmp/Idris2
  make -C /tmp/Idris2 bootstrap SCHEME=chezscheme
  make -C /tmp/Idris2 install
fi

"$HOME/.idris2/bin/idris2" --version
