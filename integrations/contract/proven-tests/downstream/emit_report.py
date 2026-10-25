#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# Minimal downstream emitter: turn a flat list of executed test results into a
# Proven-Tests schema_version-2 run report.
#
# This is the *producer* half of the downstream contract. A Rust repository
# would call its own test runner (`cargo test`, a custom harness, an FFI-parity
# runner) and hand the same facts to `proven-evidence emit`; the report it
# writes is byte-for-byte the document `check_contract.py` validates.
#
# Honesty rules enforced here, mirroring src/ProvenTests/Types.idr:
#   * a downstream repository cannot claim ActuallyProven — that tier requires
#     an Idris2 proof ladder checked by the type checker, which only the
#     Idris2 toolchain can produce. Refused, not silently downgraded.
#   * ProvisionallyProven requires its framework-safety and test-safety
#     certificates to be supplied.
#   * coverage is DERIVED from entries whose outcome is "passed"; it is never
#     taken from the input. A report can therefore not claim a cell it did not
#     run.
#
# EXIT CODES: 0 written; 1 a test fact is dishonest or malformed; 2 the input
# could not be read or parsed (NO CHECK WAS PERFORMED).

from __future__ import annotations

import json
import sys
from typing import Any

TIERS = ("Unproven", "ProvisionallyProven")
OUTCOMES = ("passed", "failed", "error", "skipped")
OBLIGATIONS = ("Fixtures", "CannotFailByDesign", "FixtureDebt")


def fail(msg: str, code: int) -> "None":
    print(f"emit_report: {msg}", file=sys.stderr)
    raise SystemExit(code)


def emit(input_doc: Any) -> dict:
    if not isinstance(input_doc, dict):
        fail("input is not a JSON object", 2)
    tests = input_doc.get("tests")
    if not isinstance(tests, list):
        fail("input has no 'tests' array", 2)

    entries: list[dict] = []
    covered: set[tuple[str, str]] = set()
    counts = {"passed": 0, "failed": 0, "error": 0, "skipped": 0}
    tiers = {"ActuallyProven": 0, "ProvisionallyProven": 0, "Unproven": 0}
    debt = 0

    for i, t in enumerate(tests):
        where = f"tests[{i}]"
        if not isinstance(t, dict):
            fail(f"{where} is not an object", 1)
        tier = t.get("tier")
        if tier not in TIERS:
            fail(
                f"{where}.tier {tier!r}: a downstream repository may only claim "
                f"{TIERS}; ActuallyProven needs an Idris2 proof ladder",
                1,
            )
        outcome = t.get("outcome")
        if outcome not in OUTCOMES:
            fail(f"{where}.outcome {outcome!r} is not one of {OUTCOMES}", 1)
        ob = t.get("fixture_obligation", "Fixtures")
        if ob not in OBLIGATIONS:
            fail(f"{where}.fixture_obligation {ob!r} is not one of {OBLIGATIONS}", 1)
        if ob == "FixtureDebt" and not t.get("fixture_debt_ref"):
            fail(f"{where} is FixtureDebt without a fixture_debt_ref", 1)

        evidence: dict = {}
        if tier == "ProvisionallyProven":
            if not t.get("framework_safety") or not t.get("test_safety"):
                fail(f"{where} claims ProvisionallyProven without its certificates", 1)
            evidence = {"framework_safety": t["framework_safety"], "test_safety": t["test_safety"]}

        result: dict = {"outcome": outcome}
        if outcome != "passed" and t.get("message"):
            result["message"] = t["message"]

        entry: dict = {
            "test_id": {
                "module_path": t.get("module", ""),
                "test_name": t.get("name", ""),
                "line_number": int(t.get("line", 0)),
            },
            "category": t.get("category"),
            "aspect": t.get("aspect"),
            "typesafe_category": t.get("typesafe_category"),
            "provenance": tier,
            "evidence": evidence,
            "proof_ladder": [],
            "result": result,
            "fixture_obligation": ob,
        }
        if t.get("oracle_provenance"):
            entry["oracle_provenance"] = t["oracle_provenance"]
        if ob == "Fixtures":
            entry["fixtures"] = {
                "silence": t.get("silence", {"source": "RuntimeConstructed", "description": ""}),
                "firing": t.get("firing", {"source": "RuntimeConstructed", "defect_class": ""}),
            }
        if t.get("duration_ms") is not None:
            entry["duration_ms"] = int(t["duration_ms"])

        if ob == "FixtureDebt":
            debt += 1
            entry["fixture_debt_ref"] = t["fixture_debt_ref"]
        else:
            counts[outcome] += 1
            tiers[tier] += 1
            if outcome == "passed" and t.get("category") and t.get("aspect"):
                covered.add((t["category"], t["aspect"]))

        entries.append(entry)

    report = {
        "schema_version": 2,
        "suite": input_doc.get("suite", "proven-tests-downstream"),
        "generated_at": input_doc.get("generated_at", ""),
        "toolchain": input_doc.get("toolchain", {}),
        "summary": {
            "passed": counts["passed"],
            "failed": counts["failed"],
            "errors": counts["error"],
            "skipped": counts["skipped"],
            "total": len(entries) - debt,
            "actually_proven": tiers["ActuallyProven"],
            "provisionally_proven": tiers["ProvisionallyProven"],
            "unproven": tiers["Unproven"],
            "covered_cells": len(covered),
            "cat_aspect_cells": input_doc.get("cat_aspect_cells", 238),
            "lattice_covered": len(covered),
        },
        "entries": entries,
    }
    return report


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    in_path, out_path = argv[1], argv[2]
    try:
        with open(in_path, encoding="utf-8") as fh:
            doc = json.load(fh)
    except OSError as exc:
        fail(f"cannot read {in_path}: {exc}", 2)
    except json.JSONDecodeError as exc:
        fail(f"{in_path} is not valid JSON: {exc}", 2)
    report = emit(doc)
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")
    print(
        f"wrote {out_path}: {report['summary']['passed']}/{report['summary']['total']} passed, "
        f"{report['summary']['covered_cells']} covered cell(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
