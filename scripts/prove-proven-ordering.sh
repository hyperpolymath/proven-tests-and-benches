#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Prove proven's vector-clock laws against proven itself, at a pinned SHA.
#
# Usage: scripts/prove-proven-ordering.sh <proven_git_checkout>
#
# integrations/proven/PROVEN_PIN names one commit of hyperpolymath/proven. This
# script extracts proven's src/ at exactly that commit (`git archive`, so the
# checkout's working tree and branch do not matter, only that it holds the
# commit), installs Proven.SafeOrdering as the package `proven-safeordering`
# into a throwaway prefix, then builds and runs
# integrations/proven/proven-ordering-laws.ipkg against it.
#
# WHY A THROWAWAY PREFIX
# ----------------------
# The toolchain's own prefix is shared by every Idris2 build on the machine;
# installing a partial proven package there would shadow any real `proven`
# install. The throwaway prefix links every package already installed in the
# toolchain prefix (prelude, base, contrib, the freshly installed proven-tests)
# and adds proven-safeordering beside them; it is deleted on exit.
#
# Exit status: 0 when every law test passes; 1 when the build or a test fails
# (a law that no longer holds against proven at the pin is a compile error);
# 2 when the pin cannot be resolved in the given checkout.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pin_file="$repo_root/integrations/proven/PROVEN_PIN"

# Print a message to stderr and exit with the given status.
die() {
  local status="$1"
  shift
  echo "prove-proven-ordering: $*" >&2
  exit "$status"
}

[ "$#" -eq 1 ] || die 2 "usage: $0 <proven_git_checkout>"
proven_root="$1"

pin="$(tr -d '[:space:]' < "$pin_file")"
[[ "$pin" =~ ^[0-9a-f]{40}$ ]] || die 2 "PROVEN_PIN is not a 40-hex commit SHA: '$pin'"
git -C "$proven_root" cat-file -e "${pin}^{commit}" 2>/dev/null \
  || die 2 "commit $pin (PROVEN_PIN) is not present in $proven_root"

idris_version="$(idris2 --libdir)"
idris_version="$(basename "$idris_version")"
base_libdir="${PROVEN_LAWS_BASE_LIBDIR:-$(idris2 --libdir)}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "--- extracting proven src/ at $pin ---"
mkdir -p "$work/proven"
git -C "$proven_root" archive "$pin" src | tar -x -C "$work/proven"
[ -f "$work/proven/src/Proven/SafeOrdering.idr" ] \
  || die 2 "src/Proven/SafeOrdering.idr does not exist at $pin"

echo "--- preparing throwaway package prefix ---"
prefix_libdir="$work/prefix/$idris_version"
mkdir -p "$prefix_libdir"
for entry in "$base_libdir"/*; do
  ln -s "$entry" "$prefix_libdir/$(basename "$entry")"
done

cat > "$work/proven-safeordering.ipkg" <<EOF
package proven-safeordering
version = 0.0.0
sourcedir = "$work/proven/src"
builddir = "$work/build"
modules = Proven.SafeOrdering
EOF

echo "--- installing proven-safeordering (Proven.SafeOrdering at $pin) ---"
( cd "$work" && IDRIS2_PREFIX="$work/prefix" idris2 --install proven-safeordering.ipkg )

echo "--- building proven-ordering-laws (a broken law fails here) ---"
cd "$repo_root/integrations/proven"
IDRIS2_PREFIX="$work/prefix" idris2 --build proven-ordering-laws.ipkg

echo "--- running proven-ordering-laws ---"
./build/exec/proven-ordering-laws
