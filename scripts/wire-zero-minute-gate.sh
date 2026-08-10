#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# wire-zero-minute-gate.sh — one-command wiring of the zero-minute CI gate.
#
# Run ONCE on owned compute (needs `gh` authenticated with admin scope on the
# repo). It:
#   1. runs the checks and posts the owned-compute/<ctx> commit status (the gate)
#   2. enables a branch-protection rule that REQUIRES that status context
# After this, PRs are gated by checks run on your own hardware — zero hosted
# GitHub Actions minutes. Idempotent; --dry-run shows what it would do.
#
# Usage: scripts/wire-zero-minute-gate.sh [--dry-run] [--repo=O/R] [--branch=main] [--context=CTX]


# ============================================================================
# REFUSAL GUARD (DEBT I-2, 2026-08-10) — this script is SUPERSEDED and would
# WEAKEN branch protection if run today:
#   - it PUTs protection with required_pull_request_reviews: null and
#     enforce_admins: false, clearing the live ruleset's protections;
#   - it requires the `owned-compute/idris2` context, which no longer reports;
#   - it does NOT require `Build, test and benchmark`, which is the context
#     that actually gates (required since 2026-08-10).
# It is retained because the owned-compute mechanism is correct for
# self-hosted use. To run it anyway, set WIRE_ZERO_MINUTE_I_UNDERSTAND=1 and
# update the required contexts below to the CURRENT gating set first.
# ============================================================================
if [ "${WIRE_ZERO_MINUTE_I_UNDERSTAND:-0}" != "1" ]; then
  echo "REFUSED: scripts/wire-zero-minute-gate.sh is superseded and would weaken" >&2
  echo "         branch protection (see DEBT.md I-2 and the header above)." >&2
  exit 2
fi

set -uo pipefail

CONTEXT="${GATE_CONTEXT:-owned-compute/idris2}"
BRANCH="${GATE_BRANCH:-main}"
DRY_RUN=0
REPO=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --repo=*)    REPO="${arg#*=}" ;;
    --branch=*)  BRANCH="${arg#*=}" ;;
    --context=*) CONTEXT="${arg#*=}" ;;
    -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

here="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$REPO" ] && command -v gh >/dev/null 2>&1; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
[ -z "$REPO" ] && { echo "could not determine repo; pass --repo=OWNER/NAME" >&2; exit 2; }

echo "== wiring zero-minute gate :: repo=$REPO branch=$BRANCH context=$CONTEXT =="

# Step 1 — run the checks on owned compute and post the verdict as a commit status.
echo "-- step 1: post owned-compute verdict --"
gate_args=(--repo="$REPO" --context="$CONTEXT")
[ "$DRY_RUN" = 1 ] && gate_args+=(--dry-run)
bash "$here/owned-compute-gate.sh" "${gate_args[@]}" \
  || echo "(note: verdict was not green — the status was still posted as failure)"

# Step 2 — require that context on the base branch (the merge gate).
echo "-- step 2: require '$CONTEXT' on '$BRANCH' --"
read -r -d '' BODY <<JSON || true
{
  "required_status_checks": { "strict": false, "contexts": ["$CONTEXT"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON

if [ "$DRY_RUN" = 1 ]; then
  echo "[dry-run] gh api -X PUT repos/$REPO/branches/$BRANCH/protection --input - <<<"
  printf '%s\n' "$BODY"
  exit 0
fi

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh not found" >&2; exit 2; }
if printf '%s' "$BODY" | gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - >/dev/null; then
  echo "OK: '$CONTEXT' is now a required check on '$BRANCH' (0 hosted minutes)."
else
  echo "ERROR: could not set branch protection — the token needs admin scope on $REPO." >&2
  exit 2
fi
