// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Rust twin of the downstream Proven-Tests integration contract.
//
// It reads and validates the SAME schema_version-2 run report that
// integrations/contract/check_contract.py validates (and that
// integrations/contract/proven-tests/downstream/emit_report.py writes), so the
// contract's four rules hold in two independent implementations:
//
//   * every entry carries a test id, a provenance, a result outcome and a
//     fixture obligation;
//   * coverage is DERIVED from the entries whose outcome is `passed`;
//   * a tier may not be carried by evidence it does not have (ActuallyProven
//     needs a theorem-and-statement on every ladder rung; ProvisionallyProven
//     needs both certificates);
//   * the summary is a derived view — a summary that disagrees with the entries
//     is refused, never trusted.
//
// Deliberately mirrors the Python checker field-for-field, including one
// non-obvious counting rule: FixtureDebt entries are excluded from the test
// ledger (total / passed / failed / error / skipped / covered cells) but still
// contribute to the tier tally, because the report states what the test's
// intended tier IS even while it is not counted as a test.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;

pub const TIERS: [&str; 3] = ["ActuallyProven", "ProvisionallyProven", "Unproven"];
pub const OUTCOMES: [&str; 4] = ["passed", "failed", "error", "skipped"];
pub const FIXTURE_OBLIGATIONS: [&str; 3] = ["Fixtures", "CannotFailByDesign", "FixtureDebt"];
/// The taxonomy's full (category, aspect) lattice, as pinned in
/// integrations/contract/contract-version.json.
pub const LATTICE_CELLS: i64 = 238;

/// Python truthiness for JSON values, used by the normative checker.
fn is_truthy(value: &Value) -> bool {
    match value {
        Value::Null => false,
        Value::Bool(value) => *value,
        Value::Number(value) => value.as_f64() != Some(0.0),
        Value::String(value) => !value.is_empty(),
        Value::Array(value) => !value.is_empty(),
        Value::Object(value) => !value.is_empty(),
    }
}

/// Map a provenance tier to its summary key, defaulting to `unproven`.
fn summary_key(tier: &str) -> &'static str {
    match tier {
        "ActuallyProven" => "actually_proven",
        "ProvisionallyProven" => "provisionally_proven",
        _ => "unproven",
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestId {
    pub module_path: String,
    pub test_name: String,
    #[serde(default)]
    pub line_number: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rung {
    pub statement: String,
    #[serde(default)]
    pub theorem: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TestResult {
    pub outcome: String,
    #[serde(default)]
    pub message: Option<String>,
}

/// One entry of a schema_version-2 run report.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub test_id: TestId,
    pub category: String,
    pub aspect: String,
    #[serde(default)]
    pub typesafe_category: Option<String>,
    pub provenance: String,
    #[serde(default)]
    pub evidence: Value,
    #[serde(default)]
    pub proof_ladder: Vec<Rung>,
    pub result: TestResult,
    pub fixture_obligation: String,
    #[serde(default)]
    pub fixtures: Option<Value>,
    #[serde(default)]
    pub duration_ms: Option<i64>,
    #[serde(default)]
    pub fixture_debt_ref: Option<String>,
}

impl Entry {
    /// The (category, aspect) cell this entry maps onto.
    pub fn cell(&self) -> (String, String) {
        (self.category.clone(), self.aspect.clone())
    }
}

/// The summary a repository submits alongside its entries.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Summary {
    pub passed: i64,
    pub failed: i64,
    pub errors: i64,
    pub skipped: i64,
    pub total: i64,
    pub actually_proven: i64,
    pub provisionally_proven: i64,
    pub unproven: i64,
    pub covered_cells: i64,
    pub cat_aspect_cells: i64,
    pub lattice_covered: i64,
}

/// The full report document.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Report {
    pub schema_version: i64,
    #[serde(default)]
    pub suite: String,
    pub summary: Summary,
    pub entries: Vec<Entry>,
}

/// Parse the whole report. A structural problem (no `entries`, a malformed
/// entry) is an Err — no check could be performed on it.
/// A schema version other than 2 also returns Err. Successful parsing does
/// not validate evidence or check that the summary agrees with the entries.
pub fn parse(doc: &Value) -> Result<Report, String> {
    let report: Report = serde_json::from_value(doc.clone())
        .map_err(|e| format!("report is malformed: {e}"))?;
    if report.schema_version != 2 {
        return Err(format!(
            "schema_version must be 2, got {}",
            report.schema_version
        ));
    }
    Ok(report)
}

/// Validate tier evidence, fixture obligations and derived summary counts.
///
/// Returns detected violations, including malformed entries and an absent
/// summary. Like `validate_proven_report` in check_contract.py, coverage counts
/// distinct cells from passed, non-debt entries. This checks `covered_cells`,
/// outcome counts, `total` and tier tallies; it does not check `lattice_covered`
/// or `cat_aspect_cells`.
///
/// # Errors
/// Returns Err if the report is not an object or has no `entries` array.
pub fn validate(doc: &Value) -> Result<Vec<String>, String> {
    let mut v: Vec<String> = Vec::new();
    if !doc.is_object() {
        return Err("report is not a JSON object".to_string());
    }
    if doc.get("schema_version").and_then(Value::as_i64) != Some(2) {
        v.push("schema_version must be 2".to_string());
    }
    let entries = doc
        .get("entries")
        .and_then(Value::as_array)
        .ok_or_else(|| "report has no 'entries' array".to_string())?;

    let mut passed_cells: BTreeSet<(String, String)> = BTreeSet::new();
    let mut tier_counts = [0i64; 3];
    let mut passed = 0i64;
    let mut failed = 0i64;
    let mut errored = 0i64;
    let mut skipped = 0i64;
    let mut debt = 0i64;

    for (i, e) in entries.iter().enumerate() {
        let where_ = format!("entries[{i}]");
        let entry: Entry = match serde_json::from_value(e.clone()) {
            Ok(entry) => entry,
            Err(err) => {
                v.push(format!("{where_} is malformed: {err}"));
                continue;
            }
        };

        let tier = entry.provenance.as_str();
        if let Some(pos) = TIERS.iter().position(|t| *t == tier) {
            tier_counts[pos] += 1;
        } else {
            v.push(format!("{where_}.provenance {tier:?} is not one of {TIERS:?}"));
        }

        let outcome = entry.result.outcome.as_str();
        if !OUTCOMES.contains(&outcome) {
            v.push(format!(
                "{where_}.result.outcome {outcome:?} is not one of {OUTCOMES:?}"
            ));
            continue;
        }

        // Tier honesty: the evidence a tier claims must be present.
        match tier {
            "ActuallyProven" => {
                if entry.proof_ladder.is_empty() {
                    v.push(format!("{where_} claims ActuallyProven with an empty proof ladder"));
                }
                for (j, rung) in entry.proof_ladder.iter().enumerate() {
                    if !is_truthy(&e["proof_ladder"][j]["theorem"]) {
                        v.push(format!("{where_}.proof_ladder[{j}] has no cited theorem"));
                    }
                    if rung.statement.trim().is_empty() {
                        v.push(format!(
                            "{where_}.proof_ladder[{j}] has no stated proposition"
                        ));
                    }
                }
            }
            "ProvisionallyProven" => {
                if !is_truthy(&entry.evidence["framework_safety"]) {
                    v.push(format!(
                        "{where_} claims ProvisionallyProven without framework_safety"
                    ));
                }
                if !is_truthy(&entry.evidence["test_safety"]) {
                    v.push(format!(
                        "{where_} claims ProvisionallyProven without test_safety"
                    ));
                }
            }
            "Unproven" => {
                if !entry.proof_ladder.is_empty() {
                    v.push(format!(
                        "{where_} is Unproven but carries a non-empty proof ladder"
                    ));
                }
            }
            _ => {}
        }

        // Fixture doctrine: every test states its position; debt is named.
        let ob = entry.fixture_obligation.as_str();
        if !FIXTURE_OBLIGATIONS.contains(&ob) {
            v.push(format!(
                "{where_}.fixture_obligation {ob:?} is not one of {FIXTURE_OBLIGATIONS:?}"
            ));
        }
        if ob == "FixtureDebt" && !is_truthy(&e["fixture_debt_ref"]) {
            v.push(format!("{where_} is FixtureDebt without a fixture_debt_ref"));
        }
        if ob == "Fixtures" {
            let has_silence = is_truthy(&e["fixtures"]["silence"]);
            let has_firing = is_truthy(&e["fixtures"]["firing"]);
            if !has_silence || !has_firing {
                v.push(format!("{where_} is Fixtures without a silence/firing pair"));
            }
        }

        // Counting: debt-marked entries are not tests in any ledger.
        if ob == "FixtureDebt" {
            debt += 1;
            continue;
        }
        match outcome {
            "passed" => {
                passed += 1;
                passed_cells.insert(entry.cell());
            }
            "failed" => failed += 1,
            "error" => errored += 1,
            _ => skipped += 1,
        }
    }

    let summary = match doc.get("summary") {
        Some(s) if s.is_object() => s,
        _ => {
            v.push("report has no summary object".to_string());
            return Ok(v);
        }
    };
    let get = |key: &str| summary.get(key).and_then(Value::as_i64);

    let derived = passed_cells.len() as i64;
    if get("covered_cells") != Some(derived) {
        v.push(format!(
            "summary.covered_cells={:?} but only {derived} (category x aspect) cell(s) are \
             backed by an entry that ran and passed",
            get("covered_cells")
        ));
    }
    if get("passed") != Some(passed) {
        v.push(format!(
            "summary.passed={:?} but {passed} passed",
            get("passed")
        ));
    }
    if get("failed") != Some(failed) {
        v.push(format!("summary.failed={:?} but {failed} failed", get("failed")));
    }
    if get("errors") != Some(errored) {
        v.push(format!("summary.errors={:?} but {errored} errored", get("errors")));
    }
    if get("skipped") != Some(skipped) {
        v.push(format!("summary.skipped={:?} but {skipped} skipped", get("skipped")));
    }
    if get("total") != Some(entries.len() as i64 - debt) {
        v.push(format!(
            "summary.total={:?} but {} non-debt entries (debt-marked entries are not counted)",
            get("total"),
            entries.len() as i64 - debt
        ));
    }
    for (pos, tier) in TIERS.iter().enumerate() {
        if get(summary_key(tier)) != Some(tier_counts[pos]) {
            v.push(format!(
                "summary.{}={:?} but {}",
                summary_key(tier),
                get(summary_key(tier)),
                tier_counts[pos]
            ));
        }
    }

    Ok(v)
}

/// Derive the summary from the entries alone. Nothing is read out of the
/// report's own summary: `covered_cells` and `lattice_covered` are the distinct
/// (category, aspect) cells of the entries that ran and passed.
///
/// `FixtureDebt` entries contribute only to recognised tier tallies. The
/// `lattice_cells` value is copied to `cat_aspect_cells` without validation;
/// an empty slice produces zero entry and coverage counts. Entries are not validated:
/// unrecognised outcomes count as skipped and unrecognised tiers are not tallied.
pub fn summarise(entries: &[Entry], lattice_cells: i64) -> Summary {
    let mut passed = 0i64;
    let mut failed = 0i64;
    let mut errored = 0i64;
    let mut skipped = 0i64;
    let mut debt = 0i64;
    let mut tier_counts = [0i64; 3];
    let mut cells: BTreeSet<(String, String)> = BTreeSet::new();

    for e in entries {
        if let Some(pos) = TIERS.iter().position(|t| *t == e.provenance.as_str()) {
            tier_counts[pos] += 1;
        }
        if e.fixture_obligation == "FixtureDebt" {
            debt += 1;
            continue;
        }
        match e.result.outcome.as_str() {
            "passed" => {
                passed += 1;
                cells.insert(e.cell());
            }
            "failed" => failed += 1,
            "error" => errored += 1,
            _ => skipped += 1,
        }
    }

    let covered = cells.len() as i64;
    Summary {
        passed,
        failed,
        errors: errored,
        skipped,
        total: entries.len() as i64 - debt,
        actually_proven: tier_counts[0],
        provisionally_proven: tier_counts[1],
        unproven: tier_counts[2],
        covered_cells: covered,
        cat_aspect_cells: lattice_cells,
        lattice_covered: covered,
    }
}

/// Recompute the summary and compare it against the submitted one. The summary
/// is a derived view; if it disagrees with the entries, the report is malformed.
/// The submitted `cat_aspect_cells` is reused, so the lattice size is not checked.
///
/// # Errors
/// Returns Err describing the computed and submitted summaries if they differ.
pub fn assert_summary_matches(
    entries: &[Entry],
    submitted: &Summary,
) -> Result<(), String> {
    let computed = summarise(entries, submitted.cat_aspect_cells);
    if computed != *submitted {
        return Err(format!(
            "summary does not match the entries: computed {computed:?}, submitted {submitted:?}"
        ));
    }
    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;
    use serde_json::json;

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
        serde_json::from_value(doc.get("entries").cloned().unwrap())
            .expect("entries parse")
    }

    #[test]
    fn passed_entries_contribute_their_cell_once() {
        let doc = conforming(vec![
            entry("Unproven", "passed", "wiring", "boundary"),
            entry("Unproven", "passed", "wiring", "boundary"),
            entry("Unproven", "passed", "wiring", "typing"),
        ]);
        assert!(validate(&doc).unwrap().is_empty());
        let s = summarise(&entries_of(&doc), LATTICE_CELLS);
        assert_eq!(s.total, 3);
        assert_eq!(s.passed, 3);
        assert_eq!(s.covered_cells, 2, "duplicates must not inflate coverage");
        assert_eq!(s.lattice_covered, 2);
    }

    #[test]
    fn failed_entries_contribute_nothing() {
        let doc = conforming(vec![entry("Unproven", "failed", "wiring", "boundary")]);
        assert!(validate(&doc).unwrap().is_empty());
        let s = summarise(&entries_of(&doc), LATTICE_CELLS);
        assert_eq!(s.passed, 0);
        assert_eq!(s.covered_cells, 0);
        assert_eq!(s.failed, 1);
    }

    #[test]
    fn skipped_entries_contribute_nothing() {
        let doc = conforming(vec![
            entry("Unproven", "passed", "wiring", "boundary"),
            entry("Unproven", "skipped", "wiring", "typing"),
        ]);
        assert!(validate(&doc).unwrap().is_empty());
        let s = summarise(&entries_of(&doc), LATTICE_CELLS);
        assert_eq!(s.covered_cells, 1);
        assert_eq!(s.skipped, 1);
    }

    #[test]
    fn actually_proven_needs_a_complete_ladder() {
        let mut doc = conforming(vec![entry("ActuallyProven", "passed", "wiring", "boundary")]);
        let violations = validate(&doc).unwrap();
        assert!(violations.iter().any(|x| x.contains("empty proof ladder")));
        // A complete ladder makes it conformant.
        let mut e = entry("ActuallyProven", "passed", "wiring", "boundary");
        e["proof_ladder"] = json!([{"statement": "boom", "theorem": "idris_proof"}]);
        doc = conforming(vec![e]);
        assert!(validate(&doc).unwrap().is_empty());
    }

    #[test]
    fn provisionally_proven_needs_both_certificates() {
        let mut e = entry("ProvisionallyProven", "passed", "wiring", "boundary");
        assert!(validate(&conforming(vec![e.clone()]))
            .unwrap()
            .iter()
            .any(|x| x.contains("framework_safety")));
        e["evidence"] = json!({"framework_safety": {"x": 1}});
        assert!(validate(&conforming(vec![e.clone()]))
            .unwrap()
            .iter()
            .any(|x| x.contains("test_safety")));
        e["evidence"] = json!({"framework_safety": {"x": 1}, "test_safety": {"y": 2}});
        assert!(validate(&conforming(vec![e])).unwrap().is_empty());
    }

    #[test]
    fn unknown_provenance_is_refused_not_defaulted() {
        let doc = conforming(vec![entry("DefinitelyProven", "passed", "wiring", "boundary")]);
        assert!(validate(&doc)
            .unwrap()
            .iter()
            .any(|x| x.contains("provenance")));
    }

    #[test]
    fn overclaimed_summary_is_refused() {
        let mut doc = conforming(vec![entry("Unproven", "passed", "wiring", "boundary")]);
        assert!(validate(&doc).unwrap().is_empty());
        doc["summary"]["covered_cells"] = json!(40);
        doc["summary"]["lattice_covered"] = json!(40);
        let violations = validate(&doc).unwrap();
        assert!(violations.iter().any(|x| x.contains("covered_cells")));
    }

    #[test]
    fn debt_entries_are_excluded_from_the_ledger() {
        let mut debt = entry("Unproven", "passed", "wiring", "boundary");
        debt["fixture_obligation"] = json!("FixtureDebt");
        debt["fixture_debt_ref"] = json!("DEBT-B2-LEGACY-SUITE");
        debt.as_object_mut().unwrap().remove("fixtures");
        // The emitted summary counts it in the tier tally (the report states what
        // the intended tier IS) but not in `total`: one entry, zero tests.
        let mut doc = conforming(vec![entry("Unproven", "passed", "wiring", "typing"), debt]);
        assert!(validate(&doc).unwrap().is_empty());
        let s = summarise(&entries_of(&doc), LATTICE_CELLS);
        assert_eq!(s.total, 1, "the debt entry is not a test");
        assert_eq!(s.unproven, 2, "it still states its intended tier");
        doc["summary"]["total"] = json!(2);
        assert!(validate(&doc)
            .unwrap()
            .iter()
            .any(|x| x.contains("debt-marked entries are not counted")));
    }

    #[test]
    fn summary_is_recomputed_not_trusted() {
        let doc = conforming(vec![
            entry("Unproven", "passed", "wiring", "boundary"),
            entry("Unproven", "passed", "wiring", "typing"),
        ]);
        let entries = entries_of(&doc);
        let computed = summarise(&entries, LATTICE_CELLS);
        assert!(assert_summary_matches(&entries, &computed).is_ok());
        let mut bogus = computed.clone();
        bogus.covered_cells = 40;
        assert!(assert_summary_matches(&entries, &bogus).is_err());
    }
}
