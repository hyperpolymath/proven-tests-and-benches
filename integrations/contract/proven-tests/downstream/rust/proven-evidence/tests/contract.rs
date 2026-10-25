// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// The downstream Proven-Tests contract, asserted against the Rust reader. The
// same assertions live in Python (integrations/contract/check_contract.py) and
// in the bash fixture runner: the schema's rules — a test id, a provenance, a
// result and a fixture obligation on every entry; coverage DERIVED from the
// entries that ran and passed; no cell counted twice; no tier carried by
// evidence it lacks; and the summary is a derived view, never a claim.

use proven_evidence::{assert_summary_matches, parse, summarise, Entry, LATTICE_CELLS};
use serde_json::{json, Value};

fn entry(provenance: &str, outcome: &str, category: &str, aspect: &str) -> Value {
    json!({
        "test_id": {"module_path": "fixture.X", "test_name": "t", "line_number": 1},
        "category": category,
        "aspect": aspect,
        "typesafe_category": null,
        "provenance": provenance,
        "evidence": {},
        "proof_ladder": [],
        "result": {"outcome": outcome},
        "fixture_obligation": "Fixtures",
        "fixtures": {
            "silence": {"source": "RuntimeConstructed", "description": "clean"},
            "firing": {"source": "RuntimeConstructed", "defect_class": "declared"}
        },
        "duration_ms": 1
    })
}

/// A report whose summary is computed from its entries — i.e. an honest one.
fn conforming(entries: Vec<Value>) -> Value {
    let parsed: Vec<Entry> = entries
        .iter()
        .map(|e| serde_json::from_value(e.clone()).unwrap())
        .collect();
    let summary = summarise(&parsed, LATTICE_CELLS);
    json!({
        "schema_version": 2,
        "suite": "proven-tests-contract-fixture",
        "summary": summary,
        "entries": entries
    })
}

fn entries_of(doc: &Value) -> Vec<Entry> {
    serde_json::from_value(doc.get("entries").cloned().unwrap()).expect("entries parse")
}

#[test]
fn covered_cells_come_from_passed_entries_only() {
    let doc = conforming(vec![
        entry("Unproven", "passed", "wiring", "boundary"),
        entry("Unproven", "passed", "wiring", "typing"),
        entry("Unproven", "failed", "semantics", "precision"),
        entry("Unproven", "skipped", "semantics", "soundness"),
    ]);
    assert!(proven_evidence::validate(&doc).unwrap().is_empty());
    let summary = summarise(&entries_of(&doc), LATTICE_CELLS);
    assert_eq!(summary.total, 4);
    assert_eq!(summary.passed, 2);
    assert_eq!(summary.failed, 1);
    assert_eq!(summary.skipped, 1);
    assert_eq!(
        summary.covered_cells, 2,
        "only the two passed entries' cells are covered"
    );
}

#[test]
fn skipped_entry_contributes_nothing() {
    let doc = conforming(vec![
        entry("Unproven", "passed", "wiring", "boundary"),
        entry("Unproven", "skipped", "wiring", "typing"),
    ]);
    assert!(proven_evidence::validate(&doc).unwrap().is_empty());
    let summary = summarise(&entries_of(&doc), LATTICE_CELLS);
    assert_eq!(summary.covered_cells, 1);
    assert_eq!(summary.skipped, 1);
}

#[test]
fn two_entries_in_one_cell_count_once() {
    let doc = conforming(vec![
        entry("Unproven", "passed", "wiring", "boundary"),
        entry("Unproven", "passed", "wiring", "boundary"),
    ]);
    assert!(proven_evidence::validate(&doc).unwrap().is_empty());
    let summary = summarise(&entries_of(&doc), LATTICE_CELLS);
    assert_eq!(summary.covered_cells, 1);
    assert_eq!(summary.passed, 2);
}

#[test]
fn actually_proven_without_a_ladder_is_refused() {
    let doc = conforming(vec![entry("ActuallyProven", "passed", "wiring", "boundary")]);
    let violations = proven_evidence::validate(&doc).unwrap();
    assert!(
        violations.iter().any(|x| x.contains("empty proof ladder")),
        "a proof-free ActuallyProven must be refused, not downgraded"
    );
}

#[test]
fn rung_without_a_theorem_is_refused() {
    let mut e = entry("ActuallyProven", "passed", "wiring", "boundary");
    e["proof_ladder"] = json!([{"statement": "boom", "theorem": null}]);
    let violations = proven_evidence::validate(&conforming(vec![e])).unwrap();
    assert!(violations.iter().any(|x| x.contains("no cited theorem")));
}

#[test]
fn provisional_without_certificates_is_refused() {
    let mut e = entry("ProvisionallyProven", "passed", "wiring", "boundary");
    let violations = proven_evidence::validate(&conforming(vec![e.clone()])).unwrap();
    assert!(violations.iter().any(|x| x.contains("framework_safety")));
    e["evidence"] = json!({"framework_safety": {"x": 1}});
    let violations = proven_evidence::validate(&conforming(vec![e])).unwrap();
    assert!(violations.iter().any(|x| x.contains("test_safety")));
}

#[test]
fn overclaimed_summary_is_refused() {
    let mut doc = conforming(vec![entry("Unproven", "passed", "wiring", "boundary")]);
    assert!(proven_evidence::validate(&doc).unwrap().is_empty());
    doc["summary"]["covered_cells"] = json!(40);
    doc["summary"]["lattice_covered"] = json!(40);
    let violations = proven_evidence::validate(&doc).unwrap();
    assert!(
        violations.iter().any(|x| x.contains("covered_cells")),
        "a summary claiming 40 covered cells over a 1-cell report must be refused"
    );
}

#[test]
fn fixture_debt_entries_are_excluded_from_the_ledger() {
    let mut debt = entry("Unproven", "passed", "wiring", "boundary");
    debt["fixture_obligation"] = json!("FixtureDebt");
    debt["fixture_debt_ref"] = json!("DEBT-B2-LEGACY-SUITE");
    debt.as_object_mut().unwrap().remove("fixtures");
    let doc = conforming(vec![entry("Unproven", "passed", "wiring", "typing"), debt]);
    assert!(proven_evidence::validate(&doc).unwrap().is_empty());
    let summary = summarise(&entries_of(&doc), LATTICE_CELLS);
    assert_eq!(summary.total, 1, "the debt entry is not a test");
    assert_eq!(summary.unproven, 2, "it still states its intended tier");
}

#[test]
fn unknown_provenance_is_refused_not_defaulted() {
    let doc = conforming(vec![entry("DefinitelyProven", "passed", "wiring", "boundary")]);
    let violations = proven_evidence::validate(&doc).unwrap();
    assert!(
        violations.iter().any(|x| x.contains("provenance")),
        "an unknown tier must be refused, never silently downgraded to Unproven"
    );
}

#[test]
fn emitted_summary_must_match_the_entries() {
    let doc = conforming(vec![
        entry("Unproven", "passed", "wiring", "boundary"),
        entry("Unproven", "passed", "wiring", "typing"),
    ]);
    let report = parse(&doc).expect("the report parses");
    let computed = summarise(&report.entries, LATTICE_CELLS);
    assert!(assert_summary_matches(&report.entries, &computed).is_ok());
    let mut bogus = computed.clone();
    bogus.covered_cells = 40;
    assert!(assert_summary_matches(&report.entries, &bogus).is_err());
}

#[test]
fn malformed_entries_are_reported_not_skipped() {
    let doc = conforming(vec![entry("Unproven", "passed", "wiring", "boundary")]);
    let mut broken = doc.clone();
    broken["entries"] = json!([{"not_an_entry": true}]);
    let violations = proven_evidence::validate(&broken).unwrap();
    assert!(violations.iter().any(|x| x.contains("malformed")));
}

// These are Python's falsey JSON values. Each field is removed as well, to
// exercise the distinction between a missing key and a present empty value.
#[test]
fn evidence_presence_matches_python_truthiness() {
    let falsey = [
        json!(null), json!({}), json!(""), json!([]),
        json!(false), json!(0), json!(0.0), json!(-0.0),
    ];
    let truthy = [
        json!({"certificate": false}), json!([null]), json!(" "),
        json!(true), json!(1), json!(-1), json!(0.5),
    ];
    for (container, field, reason) in [
        ("evidence", "framework_safety", "framework_safety"),
        ("evidence", "test_safety", "test_safety"),
        ("fixtures", "silence", "silence/firing pair"),
        ("fixtures", "firing", "silence/firing pair"),
    ] {
        let mut e = entry("ProvisionallyProven", "passed", "wiring", "boundary");
        e["evidence"] = json!({"framework_safety": "cert", "test_safety": "cert"});
        let baseline = conforming(vec![e]);
        assert!(proven_evidence::validate(&baseline).unwrap().is_empty());
        for value in std::iter::once(None).chain(falsey.iter().map(Some)) {
            let mut doc = baseline.clone();
            let fields = doc["entries"][0][container].as_object_mut().unwrap();
            match value {
                Some(value) => {
                    fields.insert(field.to_string(), value.clone());
                }
                None => {
                    fields.remove(field);
                }
            }
            let violations = proven_evidence::validate(&doc).unwrap();
            assert!(
                violations.iter().any(|v| v.contains(reason)),
                "{container}.{field}={value:?}: {violations:?}"
            );
        }
        for value in &truthy {
            let mut doc = baseline.clone();
            doc["entries"][0][container][field] = value.clone();
            assert!(
                proven_evidence::validate(&doc).unwrap().is_empty(),
                "{container}.{field}={value}"
            );
        }
    }
}

#[test]
fn theorem_and_debt_references_must_be_nonempty() {
    for field in ["theorem", "fixture_debt_ref"] {
        let mut e = entry("ActuallyProven", "passed", "wiring", "boundary");
        e["proof_ladder"] = json!([{"statement": "law", "theorem": "proof"}]);
        if field == "fixture_debt_ref" {
            e["fixture_obligation"] = json!("FixtureDebt");
            e[field] = json!("DEBT-1");
        }
        let baseline = conforming(vec![e]);
        assert!(proven_evidence::validate(&baseline).unwrap().is_empty());
        for value in [
            None, Some(json!(null)), Some(json!("")), Some(json!({})),
            Some(json!([])), Some(json!(false)), Some(json!(0)),
        ] {
            let mut doc = baseline.clone();
            let fields = if field == "theorem" {
                &mut doc["entries"][0]["proof_ladder"][0]
            } else {
                &mut doc["entries"][0]
            }
            .as_object_mut()
            .unwrap();
            match &value {
                Some(value) => {
                    fields.insert(field.to_string(), value.clone());
                }
                None => {
                    fields.remove(field);
                }
            }
            let violations = proven_evidence::validate(&doc).unwrap();
            // Non-string references are already rejected by typed parsing.
            let reason = if value
                .as_ref()
                .is_some_and(|v| !v.is_null() && !v.is_string())
            {
                "malformed"
            } else if field == "theorem" {
                "no cited theorem"
            } else {
                "without a fixture_debt_ref"
            };
            assert!(
                violations.iter().any(|v| v.contains(reason)),
                "{field}={value:?}: {violations:?}"
            );
        }
        // Whitespace is truthy in Python; do not trim evidence references.
        let mut doc = baseline;
        if field == "theorem" {
            doc["entries"][0]["proof_ladder"][0][field] = json!(" ");
        } else {
            doc["entries"][0][field] = json!(" ");
        }
        assert!(proven_evidence::validate(&doc).unwrap().is_empty());
    }
}
