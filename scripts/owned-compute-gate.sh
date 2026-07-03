#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# owned-compute-gate.sh — run proven-tests' real checks on OWNED COMPUTE and
# publish the verdict to GitHub as a commit status, satisfying a required check
# for ZERO GitHub Actions minutes.
#
# This is the dependency-free, in-repo embodiment of bag-of-actions'
# `Bag.GitHubBridge`: it posts via the Commit Status API (writable by a normal
# `gh` token, unlike the App-only Checks API) with a conservative mapping —
# only an all-pass run is reported `success`; anything else is `failure`, so a
# check that did not truly pass can never silently satisfy a *required* gate.
#
# Usage:
#   scripts/owned-compute-gate.sh [--dry-run] [--context=CTX] [--repo=O/R] [--sha=SHA]
#
# Env:
#   GATE_CONTEXT    required-check context string  (default: owned-compute/idris2)
#   GATE_CHECK_CMD  the command whose exit code is the verdict
#                   (default: "bash scripts/ci-build.sh")
#   GATE_TARGET_URL optional URL to attach to the status (e.g. a build log)
#
# Exit code mirrors the verdict (0 = success, 1 = failure, 2 = usage/tooling).

set -uo pipefail

CONTEXT="${GATE_CONTEXT:-owned-compute/idris2}"
CHECK_CMD="${GATE_CHECK_CMD:-bash scripts/ci-build.sh}"
TARGET_URL="${GATE_TARGET_URL:-}"
DRY_RUN=0
SHA=""
REPO=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)      DRY_RUN=1 ;;
    --context=*)    CONTEXT="${arg#*=}" ;;
    --repo=*)       REPO="${arg#*=}" ;;
    --sha=*)        SHA="${arg#*=}" ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ── resolve the commit and repository ───────────────────────────────────────
if [ -z "$SHA" ]; then
  SHA="$(git rev-parse HEAD 2>/dev/null)" || { echo "not a git repo and no --sha given" >&2; exit 2; }
fi

if [ -z "$REPO" ]; then
  if command -v gh >/dev/null 2>&1; then
    REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  fi
fi
if [ -z "$REPO" ]; then
  # Fall back to parsing the origin remote (handles git@host:O/R.git and https://host/O/R.git)
  url="$(git config --get remote.origin.url 2>/dev/null || true)"
  REPO="$(printf '%s' "$url" | sed -E 's#^(git@|ssh://git@|https?://)[^/:]+[:/]##; s#\.git$##')"
fi
if [ -z "$REPO" ]; then
  echo "could not determine owner/repo; pass --repo=OWNER/NAME" >&2; exit 2
fi

# ── run the real checks on owned compute ────────────────────────────────────
echo "owned-compute gate :: repo=$REPO sha=${SHA:0:12} context=$CONTEXT"
echo "running: $CHECK_CMD"
if $CHECK_CMD; then
  STATE="success"
  DESC="passed on owned compute (0 GitHub Actions minutes)"
else
  STATE="failure"
  DESC="failed on owned compute"
fi
# GitHub caps commit-status descriptions at 140 chars.
DESC="${DESC:0:140}"
echo "verdict: $STATE"

# ── publish the verdict as a GitHub commit status ───────────────────────────
post_args=(api --method POST "repos/$REPO/statuses/$SHA"
           -f "state=$STATE" -f "context=$CONTEXT" -f "description=$DESC")
[ -n "$TARGET_URL" ] && post_args+=(-f "target_url=$TARGET_URL")
post_args+=(--jq .url)

if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] gh ${post_args[*]}"
  [ "$STATE" = "success" ] && exit 0 || exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found — install it (or use --dry-run). No status posted." >&2
  exit 2
fi

if url="$(gh "${post_args[@]}")"; then
  echo "posted status: $url"
else
  echo "ERROR: failed to post commit status (check 'gh auth status' and token scope)" >&2
  exit 2
fi

[ "$STATE" = "success" ] && exit 0 || exit 1
