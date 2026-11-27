// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Downstream integration contract — conformance checker (Rust port of the
// former check_contract.py, which is deleted: Python is banned estate-wide).
//
// This is the executable statement of the two integration surfaces in
// docs/INTEGRATION-CONTRACT.adoc:
//
//   proven-tests     a schema_version-2 run report, validated for tier honesty
//                    and for coverage derived only from tests that ran and passed.
//   cicd-squabbler   a (required-context set, realised-runs) gate pair, validated
//                    against the "squabble != bypass" invariant.
//
// It works directly on `serde_json::Value`, with the same strictness as the
// original, so a structurally malformed input is a `ContractError` (exit 2, NO
// CHECK WAS PERFORMED) and never a silent pass.
//
// EXIT CODES: 0 every case ran and held; 1 a wrong verdict; 2 no check performed.

use serde_json::{json, Map, Value};
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

pub const TIERS: [&str; 3] = ["ActuallyProven", "ProvisionallyProven", "Unproven"];
pub const OUTCOMES: [&str; 4] = ["passed", "failed", "error", "skipped"];
pub const FIXTURE_OBLIGATIONS: [&str; 3] = ["Fixtures", "CannotFailByDesign", "FixtureDebt"];
const TIER_SUMMARY_KEY: [(&str, &str); 3] = [
    ("ActuallyProven", "actually_proven"),
    ("ProvisionallyProven", "provisionally_proven"),
    ("Unproven", "unproven"),
];

/// A structural problem that means no check could be performed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContractError(pub String);

impl std::fmt::Display for ContractError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

fn ce<T>(msg: impl Into<String>) -> Result<T, ContractError> {
    Err(ContractError(msg.into()))
}

/// Truthiness of a JSON value (null, false, 0, "", [] and {} are falsey).
pub fn truthy(v: &Value) -> bool {
    match v {
        Value::Null => false,
        Value::Bool(b) => *b,
        Value::Number(n) => n.as_f64() != Some(0.0),
        Value::String(s) => !s.is_empty(),
        Value::Array(a) => !a.is_empty(),
        Value::Object(o) => !o.is_empty(),
    }
}

/// Render a value for a violation message: strings quoted, null as `none`.
fn show(v: &Value) -> String {
    match v {
        Value::Null => "none".to_string(),
        Value::String(s) => format!("'{s}'"),
        other => other.to_string(),
    }
}

fn nonblank(v: Option<&Value>) -> bool {
    matches!(v, Some(Value::String(s)) if !s.trim().is_empty())
}

fn get<'a>(m: &'a Map<String, Value>, k: &str) -> &'a Value {
    m.get(k).unwrap_or(&Value::Null)
}

// ── proven-tests ─────────────────────────────────────────────────────────────

/// Validate a schema_version-2 run report. Returns (violations, derived
/// covered cells). An empty violation list means the report passed these checks;
/// it does not authenticate proof citations or execution.
pub fn validate_proven_report(doc: &Value) -> Result<(Vec<String>, usize), ContractError> {
    let mut v: Vec<String> = Vec::new();
    let Some(root) = doc.as_object() else {
        return ce("report is not a JSON object");
    };
    if root.get("schema_version").and_then(Value::as_i64) != Some(2) {
        v.push(format!("schema_version must be 2, got {}", show(get(root, "schema_version"))));
    }
    let Some(entries) = root.get("entries").and_then(Value::as_array) else {
        return ce("report has no 'entries' array");
    };

    let mut passed_cells: BTreeSet<(String, String)> = BTreeSet::new();
    let mut tier_counts = [0i64; 3];
    let (mut passed, mut failed, mut errored, mut skipped, mut debt) = (0i64, 0i64, 0i64, 0i64, 0i64);

    for (i, e) in entries.iter().enumerate() {
        let w = format!("entries[{i}]");
        let Some(e) = e.as_object() else {
            v.push(format!("{w} is not an object"));
            continue;
        };
        for (field, want, ok) in [
            ("evidence", "object", get(e, "evidence").is_object()),
            ("proof_ladder", "array", get(e, "proof_ladder").is_array()),
            ("category", "string", get(e, "category").is_string()),
            ("aspect", "string", get(e, "aspect").is_string()),
        ] {
            if !get(e, field).is_null() && !ok {
                return ce(format!("{w}.{field} must be {want} or null"));
            }
        }

        let tid_ok = e.get("test_id").and_then(Value::as_object).is_some_and(|t| {
            truthy(get(t, "module_path")) && truthy(get(t, "test_name"))
        });
        if !tid_ok {
            v.push(format!("{w}.test_id must carry module_path and test_name"));
        }

        let tier_v = get(e, "provenance");
        let tier = tier_v.as_str().filter(|t| TIERS.contains(t));
        match tier {
            Some(t) => tier_counts[TIERS.iter().position(|x| *x == t).unwrap_or(2)] += 1,
            None => v.push(format!("{w}.provenance {} is not one of {TIERS:?}", show(tier_v))),
        }

        let outcome_v = e
            .get("result")
            .and_then(Value::as_object)
            .map_or(&Value::Null, |r| get(r, "outcome"));
        let Some(outcome) = outcome_v.as_str().filter(|o| OUTCOMES.contains(o)) else {
            v.push(format!("{w}.result.outcome {} is not one of {OUTCOMES:?}", show(outcome_v)));
            continue;
        };

        let empty: Vec<Value> = Vec::new();
        let ladder = get(e, "proof_ladder").as_array().unwrap_or(&empty);
        let evidence = e.get("evidence").and_then(Value::as_object);
        let ev = |k: &str| evidence.is_some_and(|m| truthy(get(m, k)));
        match tier {
            Some("ActuallyProven") => {
                if ladder.is_empty() {
                    v.push(format!("{w} claims ActuallyProven with an empty proof ladder"));
                }
                for (j, rung) in ladder.iter().enumerate() {
                    let r = rung.as_object();
                    if !nonblank(r.and_then(|m| m.get("theorem"))) {
                        v.push(format!("{w}.proof_ladder[{j}] has no cited theorem"));
                    }
                    if !nonblank(r.and_then(|m| m.get("statement"))) {
                        v.push(format!("{w}.proof_ladder[{j}] has no stated proposition"));
                    }
                }
            }
            Some("ProvisionallyProven") => {
                if !ev("framework_safety") {
                    v.push(format!("{w} claims ProvisionallyProven without framework_safety"));
                }
                if !ev("test_safety") {
                    v.push(format!("{w} claims ProvisionallyProven without test_safety"));
                }
            }
            Some(_) if !ladder.is_empty() => {
                v.push(format!("{w} is Unproven but carries a non-empty proof ladder"));
            }
            _ => {}
        }

        let ob_v = get(e, "fixture_obligation");
        let ob = ob_v.as_str().unwrap_or("");
        if !FIXTURE_OBLIGATIONS.contains(&ob) {
            v.push(format!(
                "{w}.fixture_obligation {} is not one of {FIXTURE_OBLIGATIONS:?}",
                show(ob_v)
            ));
        }
        if ob == "FixtureDebt" && !truthy(get(e, "fixture_debt_ref")) {
            v.push(format!("{w} is FixtureDebt without a fixture_debt_ref"));
        }
        if ob == "Fixtures" {
            let ok = e.get("fixtures").and_then(Value::as_object).is_some_and(|p| {
                truthy(get(p, "silence")) && truthy(get(p, "firing"))
            });
            if !ok {
                v.push(format!("{w} is Fixtures without a silence/firing pair"));
            }
        }

        if ob == "FixtureDebt" {
            debt += 1;
            continue;
        }
        match outcome {
            "passed" => {
                passed += 1;
                if let (Some(c), Some(a)) = (get(e, "category").as_str(), get(e, "aspect").as_str()) {
                    if !c.is_empty() && !a.is_empty() {
                        passed_cells.insert((c.to_string(), a.to_string()));
                    }
                }
            }
            "failed" => failed += 1,
            "error" => errored += 1,
            _ => skipped += 1,
        }
    }

    let derived = passed_cells.len();
    let Some(summary) = root.get("summary").and_then(Value::as_object) else {
        v.push("report has no summary object".to_string());
        return Ok((v, derived));
    };
    let n = |k: &str| -> Option<i64> {
        summary.get(k).filter(|x| !x.is_boolean()).and_then(Value::as_i64)
    };
    let tier_keys = TIER_SUMMARY_KEY.map(|(_, k)| k);
    for key in ["covered_cells", "passed", "failed", "errors", "skipped", "total",
                "lattice_covered", "cat_aspect_cells"].iter().chain(tier_keys.iter()) {
        if !n(key).is_some_and(|x| x >= 0) {
            v.push(format!("summary.{key} must be a non-negative integer"));
        }
    }
    let shown = |k: &str| show(get(summary, k));
    let d = derived as i64;
    if n("covered_cells") != Some(d) {
        v.push(format!(
            "summary.covered_cells={} but only {d} (category x aspect) cell(s) are backed by an entry that ran and passed",
            shown("covered_cells")
        ));
    }
    for (key, want, label) in [("passed", passed, "passed"), ("failed", failed, "failed"),
                               ("errors", errored, "errored"), ("skipped", skipped, "skipped")] {
        if n(key) != Some(want) {
            v.push(format!("summary.{key}={} but {want} {label}", shown(key)));
        }
    }
    let nondebt = entries.len() as i64 - debt;
    if n("total") != Some(nondebt) {
        v.push(format!(
            "summary.total={} but {nondebt} non-debt entries (debt-marked entries are not counted)",
            shown("total")
        ));
    }
    for (pos, (_, key)) in TIER_SUMMARY_KEY.iter().enumerate() {
        if n(key) != Some(tier_counts[pos]) {
            v.push(format!("summary.{key}={} but {}", shown(key), tier_counts[pos]));
        }
    }
    if n("lattice_covered") != Some(d) {
        v.push(format!(
            "summary.lattice_covered={} but only {d} cell(s) are backed by an entry that ran and passed",
            shown("lattice_covered")
        ));
    }
    Ok((v, derived))
}

// ── cicd-squabbler ───────────────────────────────────────────────────────────

/// Map a recognised run label to its gate kind (mirrors
/// `squabble_core::gate::CheckRun::from_github`). Anything unrecognised is an error.
pub fn kind(run: &Value) -> Result<&'static str, ContractError> {
    let label = run.as_str().unwrap_or("");
    Ok(match label {
        "passed" => "Passed",
        "skipped" | "neutral" => "Skipped",
        "failed" | "error" | "timed_out" | "cancelled" | "startup_failure" => "Failed",
        "pending" => "Pending",
        "missing" => "Missing",
        _ => return ce(format!("unrecognised check run {}", show(run))),
    })
}

fn kinds(checks: &[Value]) -> Result<Vec<&'static str>, ContractError> {
    checks
        .iter()
        .map(|c| kind(c.get("run").unwrap_or(&Value::Null)))
        .collect()
}

/// The engine's `Gate::evaluate` verdict. An empty set is Blocked, never Green.
pub fn evaluate_gate(checks: &[Value]) -> Result<&'static str, ContractError> {
    if checks.is_empty() {
        return Ok("Blocked");
    }
    let ks = kinds(checks)?;
    if ks.iter().all(|k| matches!(*k, "Passed" | "Skipped")) {
        Ok("Green")
    } else if ks.contains(&"Failed") {
        Ok("Red")
    } else {
        Ok("Blocked")
    }
}

/// A green that is evidence-bearing and has dropped no required context.
pub fn legitimate_green(required: &[Value], checks: &[Value]) -> Result<bool, ContractError> {
    if evaluate_gate(checks)? != "Green" || required.is_empty() || checks.is_empty() {
        return Ok(false);
    }
    let present: BTreeSet<&str> = checks
        .iter()
        .filter_map(|c| c.get("required_context").and_then(Value::as_str))
        .collect();
    if required.iter().any(|r| !r.as_str().is_some_and(|s| present.contains(s))) {
        return Ok(false);
    }
    let ks = kinds(checks)?;
    if ks.iter().any(|k| matches!(*k, "Missing" | "Pending" | "Failed")) {
        return Ok(false);
    }
    Ok(ks.contains(&"Passed"))
}

/// Count skipped and neutral runs, which carry no passing evidence.
pub fn evidence_free(checks: &[Value]) -> Result<usize, ContractError> {
    Ok(kinds(checks)?.iter().filter(|k| **k == "Skipped").count())
}

/// Return (gate_state, is_legitimate_green, evidence_free_count).
pub fn validate_squabbler_gate(doc: &Value) -> Result<(&'static str, bool, usize), ContractError> {
    let Some(root) = doc.as_object() else {
        return ce("gate is not a JSON object");
    };
    let Some(required) = root.get("required_contexts").and_then(Value::as_array) else {
        return ce("gate has no 'required_contexts' array");
    };
    let Some(checks) = root.get("checks").and_then(Value::as_array) else {
        return ce("gate has no 'checks' array");
    };
    if required.iter().any(|c| !nonblank(Some(c))) {
        return ce("required contexts must be non-empty strings");
    }
    for c in checks {
        if !nonblank(c.get("required_context")) {
            return ce("a check is missing required_context");
        }
        kind(c.get("run").unwrap_or(&Value::Null))?;
    }
    Ok((evaluate_gate(checks)?, legitimate_green(required, checks)?, evidence_free(checks)?))
}

// ── case runner ──────────────────────────────────────────────────────────────

/// The `integrations/contract` directory. `CONTRACT_ROOT` overrides it.
pub fn default_root() -> PathBuf {
    std::env::var_os("CONTRACT_ROOT").map_or_else(
        || Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../..").to_path_buf(),
        PathBuf::from,
    )
}

fn load(path: &Path) -> Result<Value, ContractError> {
    if !path.is_file() {
        return ce(format!("missing file: {}", path.display()));
    }
    let raw = std::fs::read_to_string(path)
        .map_err(|e| ContractError(format!("cannot read {}: {e}", path.display())))?;
    serde_json::from_str(&raw)
        .map_err(|e| ContractError(format!("unparseable JSON in {}: {e}", path.display())))
}

fn surface_ok(surface: &str) -> bool {
    matches!(surface, "proven-tests" | "cicd-squabbler")
}

/// Run a surface's fixture cases, printing verdicts. Returns 0 or 1.
pub fn run_surface(root: &Path, surface: &str) -> Result<i32, ContractError> {
    let dir = root.join(surface);
    let cases_doc = load(&dir.join("cases.json"))?;
    let Some(cases) = cases_doc.get("cases").and_then(Value::as_array) else {
        return ce("cases.json has no 'cases' array");
    };
    let (mut failures, mut ran) = (0usize, 0usize);
    for case in cases {
        let id = case.get("id").and_then(Value::as_str).unwrap_or("?");
        let Some(fixture) = case.get("fixture").and_then(Value::as_str) else {
            return ce(format!("case {id} has no fixture"));
        };
        let Some(expect) = case.get("expect").and_then(Value::as_object) else {
            return ce(format!("case {id} has no expect object"));
        };
        let outcome = load(&dir.join(fixture)).and_then(|doc| {
            if surface == "proven-tests" {
                let (viol, derived) = validate_proven_report(&doc)?;
                let actual = json!({"valid": viol.is_empty(), "derived_covered_cells": derived});
                Ok((actual, viol))
            } else {
                let (state, legit, free) = validate_squabbler_gate(&doc)?;
                Ok((json!({"gate_state": state, "legitimate_green": legit, "evidence_free": free}), vec![]))
            }
        });
        let (actual, violations) = match outcome {
            Ok(pair) => pair,
            Err(err) => {
                println!("  FAIL {id}: no check performed — {err}");
                failures += 1;
                continue;
            }
        };
        ran += 1;
        let bad: Vec<String> = expect
            .iter()
            .filter(|(k, want)| actual.get(k.as_str()) != Some(*want))
            .map(|(k, want)| {
                format!("{k}={} (expected {want})", actual.get(k.as_str()).unwrap_or(&Value::Null))
            })
            .collect();
        if bad.is_empty() {
            let shown: Vec<String> = expect.iter().map(|(k, v)| format!("{k}={v}")).collect();
            println!("  ok   {id}: {}", shown.join(", "));
        } else {
            failures += 1;
            println!("  FAIL {id}: {}", bad.join("; "));
        }
        if surface == "proven-tests" {
            if let Some(reason) = case.get("expect_invalid_reason").and_then(Value::as_str) {
                if violations.is_empty() {
                    println!("  FAIL {id}: expected invalidity but report validated");
                    failures += 1;
                } else if !violations.iter().any(|t| t.contains(reason)) {
                    println!("  FAIL {id}: invalid for the wrong reason; wanted a violation mentioning '{reason}'");
                    failures += 1;
                }
            }
        }
    }
    println!("{surface}: {}/{ran} case(s) passed", ran.saturating_sub(failures));
    Ok(i32::from(failures > 0))
}

/// Print one file's report violations or gate verdict. 0 conformant, 1
/// violations, 2 no check performed.
pub fn validate_file(path: &Path, surface: &str) -> Result<i32, ContractError> {
    let doc = load(path)?;
    let (violations, derived) = if surface == "proven-tests" {
        let (viol, d) = validate_proven_report(&doc).map_err(|e| ContractError(e.0))?;
        (viol, Some(d))
    } else {
        let (state, legit, free) = validate_squabbler_gate(&doc)?;
        println!("gate_state={state} legitimate_green={legit} evidence_free={free}");
        (vec![], None)
    };
    if !violations.is_empty() {
        println!("NOT CONFORMANT:");
        for item in &violations {
            println!("  - {item}");
        }
        if let Some(d) = derived {
            println!("derived_covered_cells={d}");
        }
        return Ok(1);
    }
    println!("CONFORMANT");
    if let Some(d) = derived {
        println!("derived_covered_cells={d}");
    }
    Ok(0)
}

/// Dispatch CLI arguments (excluding the program name). Returns an exit status.
pub fn main_with(root: &Path, args: &[String]) -> i32 {
    let result = match args {
        [s] if surface_ok(s) => Some(run_surface(root, s)),
        [cmd, path, s] if cmd == "validate-file" && surface_ok(s) => {
            Some(validate_file(Path::new(path), s))
        }
        _ => None,
    };
    match result {
        Some(Ok(code)) => code,
        Some(Err(err)) => {
            println!("NO CHECK PERFORMED: {err}");
            2
        }
        None => {
            println!("Downstream evidence contract checker");
            println!("\nusage: contract-check <proven-tests|cicd-squabbler>");
            println!("       contract-check validate-file <path> <proven-tests|cicd-squabbler>");
            2
        }
    }
}
