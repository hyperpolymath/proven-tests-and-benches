#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Downstream integration contract — conformance checker.
#
# This is the *normative, executable statement* of the two integration
# surfaces documented in docs/INTEGRATION-CONTRACT.adoc:
#
#   proven-tests     a schema_version-2 run report submitted by a downstream
#                    repository, validated for tier honesty and for coverage
#                    derived only from tests that actually ran and passed.
#   cicd-squabbler   a (required-context set, realised-runs) gate pair,
#                    validated against the "squabble != bypass" invariant:
#                    no missing / skipped-only / cancelled / failed required
#                    check may yield a *legitimate* green.
#
# It is deliberately dependency-free (stdlib only) so a downstream CI can run
# it before any toolchain exists. The authoritative semantics are also
# enforced in code — the Idris2 types in src/ProvenTests/Types.idr make a
# proof-free Actually-Proven classification unrepresentable, and the SPARK
# package in cicd-squabbler/spark proves Green <=> (non-empty and all
# satisfied) — but a downstream repository cannot compile either of those
# without adopting the whole toolchain. This checker is the portable floor.
#
# EXIT CODES (the repository's standing three-outcome convention):
#   0  every case ran and every expectation held
#   1  at least one case produced the wrong verdict
#   2  NO CHECK WAS PERFORMED — a fixture or case file is missing, or a
#      fixture/case could not be parsed. Never reported as success.

from __future__ import annotations

import json
import os
import sys
from typing import Any

# ── proven-tests vocabulary ──────────────────────────────────────────────────
TIERS = ("ActuallyProven", "ProvisionallyProven", "Unproven")
TIER_SUMMARY_KEY = {
    "ActuallyProven": "actually_proven",
    "ProvisionallyProven": "provisionally_proven",
    "Unproven": "unproven",
}
OUTCOMES = ("passed", "failed", "error", "skipped")
FIXTURE_OBLIGATIONS = ("Fixtures", "CannotFailByDesign", "FixtureDebt")

# ── cicd-squabbler vocabulary ────────────────────────────────────────────────
# Mirrors squabble_core::gate::CheckRun::from_github. A completed run with an
# unrecognised conclusion is Failed, never Passed.
RUN_KIND = {
    "passed": "Passed",
    "skipped": "Skipped",
    "neutral": "Skipped",
    "failed": "Failed",
    "error": "Failed",
    "timed_out": "Failed",
    "cancelled": "Failed",
    "startup_failure": "Failed",
    "pending": "Pending",
    "missing": "Missing",
}
GATE_STATES = ("Blocked", "Red", "Green")


class ContractError(Exception):
    """A structural problem that means no check could be performed."""


# ════════════════════════════════════════════════════════════════════════════
# proven-tests
# ════════════════════════════════════════════════════════════════════════════

def _cell(entry: dict) -> tuple[str, str] | None:
    cat, asp = entry.get("category"), entry.get("aspect")
    if cat and asp:
        return (cat, asp)
    return None


def validate_proven_report(doc: Any) -> tuple[list[str], int]:
    """Validate a schema_version-2 run report.

    Returns (violations, derived_covered_cells). An empty violations list means
    the report is contract-conformant. derived_covered_cells is computed from
    the entries alone, so a caller can compare it against the report's own
    summary.
    """
    v: list[str] = []
    if not isinstance(doc, dict):
        raise ContractError("report is not a JSON object")
    if doc.get("schema_version") != 2:
        v.append(f"schema_version must be 2, got {doc.get('schema_version')!r}")

    entries = doc.get("entries")
    if not isinstance(entries, list):
        raise ContractError("report has no 'entries' array")

    passed_cells: set[tuple[str, str]] = set()
    tier_counts = dict.fromkeys(TIERS, 0)
    passed = failed = errored = skipped = debt = 0

    for i, e in enumerate(entries):
        where = f"entries[{i}]"
        if not isinstance(e, dict):
            v.append(f"{where} is not an object")
            continue

        tid = e.get("test_id")
        if not isinstance(tid, dict) or not tid.get("module_path") or not tid.get("test_name"):
            v.append(f"{where}.test_id must carry module_path and test_name")

        tier = e.get("provenance")
        if tier not in TIERS:
            v.append(f"{where}.provenance {tier!r} is not one of {TIERS}")
        else:
            tier_counts[tier] += 1

        result = e.get("result")
        outcome = result.get("outcome") if isinstance(result, dict) else None
        if outcome not in OUTCOMES:
            v.append(f"{where}.result.outcome {outcome!r} is not one of {OUTCOMES}")
            continue

        # Tier honesty: the evidence a tier claims must be present.
        ladder = e.get("proof_ladder") or []
        evidence = e.get("evidence") or {}
        if tier == "ActuallyProven":
            if not ladder:
                v.append(f"{where} claims ActuallyProven with an empty proof ladder")
            for j, rung in enumerate(ladder):
                if not isinstance(rung, dict) or not rung.get("theorem"):
                    v.append(f"{where}.proof_ladder[{j}] has no cited theorem")
                if not isinstance(rung, dict) or not str(rung.get("statement", "")).strip():
                    v.append(f"{where}.proof_ladder[{j}] has no stated proposition")
        elif tier == "ProvisionallyProven":
            if not evidence.get("framework_safety"):
                v.append(f"{where} claims ProvisionallyProven without framework_safety")
            if not evidence.get("test_safety"):
                v.append(f"{where} claims ProvisionallyProven without test_safety")
        elif ladder:
            v.append(f"{where} is Unproven but carries a non-empty proof ladder")

        # Fixture doctrine: every test states its position; debt is named.
        ob = e.get("fixture_obligation")
        if ob not in FIXTURE_OBLIGATIONS:
            v.append(f"{where}.fixture_obligation {ob!r} is not one of {FIXTURE_OBLIGATIONS}")
        if ob == "FixtureDebt" and not e.get("fixture_debt_ref"):
            v.append(f"{where} is FixtureDebt without a fixture_debt_ref")
        if ob == "Fixtures":
            pair = e.get("fixtures")
            if not isinstance(pair, dict) or not pair.get("silence") or not pair.get("firing"):
                v.append(f"{where} is Fixtures without a silence/firing pair")

        # Counting: debt-marked entries are not tests in any ledger (B.4).
        if ob == "FixtureDebt":
            debt += 1
            continue

        if outcome == "passed":
            passed += 1
            cell = _cell(e)
            if cell is not None:
                passed_cells.add(cell)
        elif outcome == "failed":
            failed += 1
        elif outcome == "error":
            errored += 1
        else:
            skipped += 1

    summary = doc.get("summary")
    if not isinstance(summary, dict):
        v.append("report has no summary object")
        return v, len(passed_cells)

    derived = len(passed_cells)
    if summary.get("covered_cells") != derived:
        v.append(
            f"summary.covered_cells={summary.get('covered_cells')} but only {derived} "
            f"(category x aspect) cell(s) are backed by an entry that ran and passed"
        )
    if summary.get("passed") != passed:
        v.append(f"summary.passed={summary.get('passed')} but {passed} passed")
    if summary.get("failed") != failed:
        v.append(f"summary.failed={summary.get('failed')} but {failed} failed")
    if summary.get("errors") != errored:
        v.append(f"summary.errors={summary.get('errors')} but {errored} errored")
    if summary.get("skipped") != skipped:
        v.append(f"summary.skipped={summary.get('skipped')} but {skipped} skipped")
    if summary.get("total") != len(entries) - debt:
        v.append(
            f"summary.total={summary.get('total')} but {len(entries) - debt} "
            f"non-debt entries (debt-marked entries are not counted)"
        )
    for tier in TIERS:
        key = TIER_SUMMARY_KEY[tier]
        if summary.get(key) != tier_counts[tier]:
            v.append(f"summary.{key}={summary.get(key)} but {tier_counts[tier]}")
    if summary.get("lattice_covered") != derived:
        v.append(
            f"summary.lattice_covered={summary.get('lattice_covered')} but only {derived} "
            f"cell(s) are backed by an entry that ran and passed"
        )

    return v, derived


# ════════════════════════════════════════════════════════════════════════════
# cicd-squabbler
# ════════════════════════════════════════════════════════════════════════════

def _kind(run: Any) -> str:
    if not isinstance(run, str) or run not in RUN_KIND:
        raise ContractError(f"unrecognised check run {run!r}")
    return RUN_KIND[run]


def evaluate_gate(checks: list[dict]) -> str:
    """The engine's Gate::evaluate, over realised runs. Green is computed."""
    if not checks:
        return "Blocked"  # an empty requirement set is unprotected, not won
    if all(_kind(c["run"]) in ("Passed", "Skipped") for c in checks):
        return "Green"
    if any(_kind(c["run"]) == "Failed" for c in checks):
        return "Red"
    return "Blocked"


def legitimate_green(required: list[str], checks: list[dict]) -> bool:
    """The downstream-facing predicate: a green that is evidence-bearing and
    that has not dropped or renamed away a required context.

    This is deliberately stricter than GateState::Green. A gate whose satisfied
    checks are all Skipped is Green by GitHub's rollup rule but proves nothing;
    a gate missing a required context it never lists is Green over a reduced set
    and is a bypass, not a win. Neither may be reported downstream as a
    legitimate green.
    """
    if evaluate_gate(checks) != "Green":
        return False
    if not required or not checks:
        return False
    present = {c["required_context"] for c in checks}
    if any(r not in present for r in required):
        return False  # a dropped or renamed-away required context
    runs = [_kind(c["run"]) for c in checks]
    if any(r in ("Missing", "Pending", "Failed") for r in runs):
        return False
    if "Passed" not in runs:
        return False  # no evidence-bearing green
    return True


def evidence_free(checks: list[dict]) -> int:
    return sum(1 for c in checks if _kind(c["run"]) == "Skipped")


def validate_squabbler_gate(doc: Any) -> tuple[str, bool, int]:
    """Return (gate_state, is_legitimate_green, evidence_free_count)."""
    if not isinstance(doc, dict):
        raise ContractError("gate is not a JSON object")
    required = doc.get("required_contexts")
    checks = doc.get("checks")
    if not isinstance(required, list):
        raise ContractError("gate has no 'required_contexts' array")
    if not isinstance(checks, list):
        raise ContractError("gate has no 'checks' array")
    for c in checks:
        if not isinstance(c, dict) or not c.get("required_context"):
            raise ContractError("a check is missing required_context")
        _kind(c.get("run"))  # structural check; raises ContractError
    return evaluate_gate(checks), legitimate_green(required, checks), evidence_free(checks)


# ════════════════════════════════════════════════════════════════════════════
# case runner
# ════════════════════════════════════════════════════════════════════════════

ROOT = os.path.dirname(os.path.abspath(__file__))


def _load(path: str) -> Any:
    if not os.path.isfile(path):
        raise ContractError(f"missing file: {path}")
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as exc:
        raise ContractError(f"unparseable JSON in {path}: {exc}") from exc


def run_surface(surface: str) -> int:
    surface_dir = os.path.join(ROOT, surface)
    cases = _load(os.path.join(surface_dir, "cases.json"))
    failures = 0
    ran = 0
    for case in cases["cases"]:
        fixture = os.path.join(surface_dir, case["fixture"])
        try:
            doc = _load(fixture)
            if surface == "proven-tests":
                violations, derived = validate_proven_report(doc)
                actual = {"valid": not violations, "derived_covered_cells": derived}
            else:
                state, legit, free = validate_squabbler_gate(doc)
                actual = {"gate_state": state, "legitimate_green": legit, "evidence_free": free}
        except ContractError as exc:
            print(f"  FAIL {case['id']}: no check performed — {exc}")
            failures += 1
            continue
        ran += 1
        expect = case["expect"]
        bad = []
        for key, want in expect.items():
            if actual.get(key) != want:
                bad.append(f"{key}={actual.get(key)!r} (expected {want!r})")
        if bad:
            failures += 1
            print(f"  FAIL {case['id']}: " + "; ".join(bad))
        else:
            print(f"  ok   {case['id']}: " + ", ".join(f"{k}={v!r}" for k, v in expect.items()))
        if surface == "proven-tests" and case.get("expect_invalid_reason"):
            reason = case["expect_invalid_reason"]
            if not violations:
                print(f"  FAIL {case['id']}: expected invalidity but report validated")
                failures += 1
            elif not any(reason in txt for txt in violations):
                print(f"  FAIL {case['id']}: invalid for the wrong reason; "
                      f"wanted a violation mentioning {reason!r}")
                failures += 1
    print(f"{surface}: {ran - failures}/{ran} case(s) passed")
    return 1 if failures else 0


def validate_file(path: str, surface: str) -> int:
    doc = _load(path)
    try:
        if surface == "proven-tests":
            violations, derived = validate_proven_report(doc)
        else:
            violations = []
            state, legit, free = validate_squabbler_gate(doc)
            print(f"gate_state={state} legitimate_green={legit} evidence_free={free}")
            derived = None
    except ContractError as exc:
        print(f"NO CHECK PERFORMED: {exc}")
        return 2
    if violations:
        print("NOT CONFORMANT:")
        for v in violations:
            print(f"  - {v}")
        if surface == "proven-tests":
            print(f"derived_covered_cells={derived}")
        return 1
    print("CONFORMANT")
    if surface == "proven-tests":
        print(f"derived_covered_cells={derived}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] in ("proven-tests", "cicd-squabbler"):
        return run_surface(argv[1])
    if len(argv) == 4 and argv[1] == "validate-file":
        return validate_file(argv[2], argv[3])
    print(__doc__.strip())
    print("\nusage: check_contract.py <proven-tests|cicd-squabbler>")
    print("       check_contract.py validate-file <path> <proven-tests|cicd-squabbler>")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
