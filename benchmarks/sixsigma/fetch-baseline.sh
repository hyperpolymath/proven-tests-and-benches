#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# fetch-baseline.sh — download the last N successful main-branch bench results
# into DIR as NNNNNNNN-<run-id>.tsv, ready for sixsigma.sh --baseline-dir DIR.
#
# Usage: fetch-baseline.sh --repo OWNER/REPO --workflow FILE --artifact TEMPLATE \
#                          [--name BENCH] --file NAME.tsv [--branch main] [--window 10] DIR
# TEMPLATE may hold the placeholders <name> (replaced by --name) and <run-id>,
# e.g. --artifact 'proven-bench-<name>' --name latency (one same-named artifact
# per run, looked up in each run). A TEMPLATE with no placeholder at all is a
# legacy PREFIX: "<PREFIX><run-id>".
# Each successful run on the branch must upload that artifact containing NAME.tsv (the same TSV that sixsigma.sh classifies). Runs whose
# artifact is missing or expired are SKIPPED and counted, not silently ignored;
# if fewer than --window usable runs are found it still exits 0 but prints the
# count so sixsigma.sh --require-full-window can be used to make that fatal.
# Needs: gh (authenticated), unzip. Exit 2 = nothing fetched.
set -eu
repo=""; wf=""; art=""; bname=""; fname=""; branch=main; window=10; dir=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;; --workflow) wf="$2"; shift 2 ;;
    --artifact) art="$2"; shift 2 ;; --file) fname="$2"; shift 2 ;; --name) bname="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;; --window) window="$2"; shift 2 ;;
    *) dir="$1"; shift ;;
  esac
done
for v in repo wf art fname dir; do [ -n "${!v}" ] || { echo "NO CHECK PERFORMED: --$v required" >&2; exit 2; }; done
case "$art" in *"<name>"*|*"<run-id>"*) legacy=0 ;; *) legacy=1 ;; esac
case "$art" in *"<name>"*) [ -n "$bname" ] || { echo "NO CHECK PERFORMED: --name required for <name> template" >&2; exit 2; } ;; esac
art=${art//"<name>"/$bname}
[ "$legacy" -eq 0 ] || art="$art<run-id>"
mkdir -p "$dir"
got=0; skipped=0
# oldest-first ordering is restored by the zero-padded sequence below
ids=$(gh api "repos/$repo/actions/workflows/$wf/runs?branch=$branch&status=success&per_page=$((window*3))" --jq '.workflow_runs[].id')
for id in $ids; do
  [ "$got" -lt "$window" ] || break
  tmp=$(mktemp -d)
  if gh run download "$id" --repo "$repo" -n "${art//"<run-id>"/$id}" -D "$tmp" >/dev/null 2>&1 && [ -s "$tmp/$fname" ]; then
    got=$((got+1)); cp "$tmp/$fname" "$dir/$(printf '%08d' "$id")-$id.tsv"
  else skipped=$((skipped+1)); fi
  rm -rf "$tmp"
done
echo "fetched $got of $window baseline runs ($skipped skipped: artifact missing/expired)"
[ "$got" -gt 0 ] || { echo "NO CHECK PERFORMED: no baseline fetched" >&2; exit 2; }
