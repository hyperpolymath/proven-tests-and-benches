// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Downstream integration contract: conformance checker and report emitter.
//
// This module is the Rust port of the former check_contract.py and
// emit_report.py. It works on raw `serde_json::Value`s, not on the typed
// `Report` in lib.rs, because the checker's job is to judge malformed input
// without trusting its shape. Messages, exit codes and output order follow the
// Python scripts so that the same fixtures give the same verdicts.
//
// SURFACES (docs/INTEGRATION-CONTRACT.adoc):
//   proven-tests     a schema_version-2 run report: tier honesty, and coverage
//                    derived only from tests that ran and passed.
//   cicd-squabbler   a (required-context set, realised-runs) gate pair:
//                    "squabble != bypass".
//
// EXIT CODES (the repository's standing three-outcome convention):
//   0  every case ran and every expectation held
//   1  at least one case produced the wrong verdict
//   2  NO CHECK WAS PERFORMED: a fixture or case file is missing or could not
//      be parsed, or the command line was wrong. Never reported as success.

use serde_json::{json, Map, Value};
use std::collections::BTreeSet;
use std::io::Write;
use std::path::{Path, PathBuf};

pub const TIERS: [&str; 3] = ["ActuallyProven", "ProvisionallyProven", "Unproven"];
const TIER_SUMMARY_KEY: [(&str, &str); 3] = [
    ("ActuallyProven", "actually_proven"),
    ("ProvisionallyProven", "provisionally_proven"),
    ("Unproven", "unproven"),
];
pub const OUTCOMES: [&str; 4] = ["passed", "failed", "error", "skipped"];
pub const FIXTURE_OBLIGATIONS: [&str; 3] = ["Fixtures", "CannotFailByDesign", "FixtureDebt"];

/// Mirrors squabble_core::gate::CheckRun::from_github. A completed run with an
/// unrecognised conclusion is Failed, never Passed.
fn run_kind(run: &str) -> Option<&'static str> {
    Some(match run {
        "passed" => "Passed",
        "skipped" | "neutral" => "Skipped",
        "failed" | "error" | "timed_out" | "cancelled" | "startup_failure" => "Failed",
        "pending" => "Pending",
        "missing" => "Missing",
        _ => return None,
    })
}

/// A structural problem that means no check could be performed.
#[derive(Debug)]
pub struct ContractError(pub String);

impl std::fmt::Display for ContractError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

fn cerr<T>(msg: impl Into<String>) -> Result<T, ContractError> {
    Err(ContractError(msg.into()))
}

// ── Python-compatible value helpers ──────────────────────────────────────────
// The verdict text quotes the offending value the way the Python checker did,
// so the same bad input gives the same words.

/// Python's `repr` of a float, for the common shapes.
fn py_float(f: f64) -> String {
    let s = format!("{f:?}");
    match s.split_once('e') {
        Some((m, e)) => {
            let (sign, digits) = match e.strip_prefix('-') {
                Some(d) => ('-', d),
                None => ('+', e),
            };
            let m = m.strip_suffix(".0").unwrap_or(m);
            format!("{m}e{sign}{digits:0>2}")
        }
        None => s,
    }
}

fn py_str_repr(s: &str) -> String {
    let quote = if s.contains('\'') && !s.contains('"') { '"' } else { '\'' };
    let mut out = String::new();
    out.push(quote);
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c == quote => {
                out.push('\\');
                out.push(c);
            }
            c if (c as u32) < 0x20 || c as u32 == 0x7f => out.push_str(&format!("\\x{:02x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push(quote);
    out
}

/// Python's `repr(value)` for a JSON-derived value.
pub fn py_repr(v: &Value) -> String {
    match v {
        Value::Null => "None".into(),
        Value::Bool(true) => "True".into(),
        Value::Bool(false) => "False".into(),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                i.to_string()
            } else if let Some(u) = n.as_u64() {
                u.to_string()
            } else {
                py_float(n.as_f64().unwrap_or(f64::NAN))
            }
        }
        Value::String(s) => py_str_repr(s),
        Value::Array(a) => format!("[{}]", a.iter().map(py_repr).collect::<Vec<_>>().join(", ")),
        Value::Object(m) => format!(
            "{{{}}}",
            m.iter()
                .map(|(k, v)| format!("{}: {}", py_str_repr(k), py_repr(v)))
                .collect::<Vec<_>>()
                .join(", ")
        ),
    }
}

/// Python's `str(value)`: like repr, but a string is itself.
fn py_str(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        other => py_repr(other),
    }
}

fn tuple_repr(items: &[&str]) -> String {
    format!(
        "({}{})",
        items.iter().map(|s| py_str_repr(s)).collect::<Vec<_>>().join(", "),
        if items.len() == 1 { "," } else { "" }
    )
}

/// Python truthiness of a JSON value.
fn truthy(v: Option<&Value>) -> bool {
    match v {
        None | Some(Value::Null) => false,
        Some(Value::Bool(b)) => *b,
        Some(Value::Number(n)) => n.as_f64().map_or(true, |f| f != 0.0),
        Some(Value::String(s)) => !s.is_empty(),
        Some(Value::Array(a)) => !a.is_empty(),
        Some(Value::Object(m)) => !m.is_empty(),
    }
}

/// Python's `str.strip()` whitespace: `str.isspace` also admits U+001C..U+001F.
fn py_space(c: char) -> bool {
    c.is_whitespace() || ('\u{1c}'..='\u{1f}').contains(&c)
}

fn blank(s: &str) -> bool {
    s.chars().all(py_space)
}

/// `value == n` as Python evaluates it for a JSON value and an int.
fn eq_int(v: Option<&Value>, n: i64) -> bool {
    match v {
        Some(Value::Bool(b)) => i64::from(*b) == n,
        Some(Value::Number(num)) => match (num.as_i64(), num.as_u64()) {
            (Some(i), _) => i == n,
            (None, Some(u)) => i128::from(u) == i128::from(n),
            _ => num.as_f64() == Some(n as f64),
        },
        _ => false,
    }
}

/// `type(value) is int and value >= 0`: a bool or float is not a count.
fn non_negative_int(v: Option<&Value>) -> bool {
    match v {
        Some(Value::Number(n)) => n.is_u64() || n.as_i64().is_some_and(|i| i >= 0),
        _ => false,
    }
}

// ════════════════════════════════════════════════════════════════════════════
// proven-tests
// ════════════════════════════════════════════════════════════════════════════

/// Validate a schema_version-2 run report. Returns (violations, derived
/// covered cells). An empty violation list means the report passed these
/// checks; it does not authenticate proof citations or execution.
///
/// Errors (no check possible): not an object, no `entries` array, or an
/// entry's evidence, proof_ladder, category or aspect has the wrong non-null
/// type.
pub fn validate_proven_report(doc: &Value) -> Result<(Vec<String>, i64), ContractError> {
    let mut v: Vec<String> = Vec::new();
    let Value::Object(doc) = doc else {
        return cerr("report is not a JSON object");
    };
    if !eq_int(doc.get("schema_version"), 2) {
        v.push(format!(
            "schema_version must be 2, got {}",
            doc.get("schema_version").map_or("None".into(), py_repr)
        ));
    }
    let Some(Value::Array(entries)) = doc.get("entries") else {
        return cerr("report has no 'entries' array");
    };

    let mut passed_cells: BTreeSet<(String, String)> = BTreeSet::new();
    let mut tier_counts = [0i64; 3];
    let (mut passed, mut failed, mut errored, mut skipped, mut debt) = (0i64, 0i64, 0i64, 0i64, 0i64);
    let tiers_repr = tuple_repr(&TIERS);
    let outcomes_repr = tuple_repr(&OUTCOMES);
    let obligations_repr = tuple_repr(&FIXTURE_OBLIGATIONS);

    for (i, e) in entries.iter().enumerate() {
        let wh = format!("entries[{i}]");
        let Value::Object(e) = e else {
            v.push(format!("{wh} is not an object"));
            continue;
        };

        for (field, expected) in [("evidence", "dict"), ("proof_ladder", "list"), ("category", "str"), ("aspect", "str")] {
            let ok = match (e.get(field), expected) {
                (None | Some(Value::Null), _) => true,
                (Some(Value::Object(_)), "dict") => true,
                (Some(Value::Array(_)), "list") => true,
                (Some(Value::String(_)), "str") => true,
                _ => false,
            };
            if !ok {
                return cerr(format!("{wh}.{field} must be {expected} or null"));
            }
        }

        let tid_ok = match e.get("test_id") {
            Some(Value::Object(t)) => truthy(t.get("module_path")) && truthy(t.get("test_name")),
            _ => false,
        };
        if !tid_ok {
            v.push(format!("{wh}.test_id must carry module_path and test_name"));
        }

        let tier_val = e.get("provenance");
        let tier = match tier_val {
            Some(Value::String(s)) if TIERS.contains(&s.as_str()) => Some(s.as_str()),
            _ => None,
        };
        match tier {
            Some(t) => {
                let idx = TIERS.iter().position(|x| *x == t).unwrap_or(0);
                tier_counts[idx] += 1;
            }
            None => v.push(format!(
                "{wh}.provenance {} is not one of {tiers_repr}",
                tier_val.map_or("None".into(), py_repr)
            )),
        }

        let outcome_val = match e.get("result") {
            Some(Value::Object(r)) => r.get("outcome"),
            _ => None,
        };
        let outcome = match outcome_val {
            Some(Value::String(s)) if OUTCOMES.contains(&s.as_str()) => s.as_str(),
            _ => {
                v.push(format!(
                    "{wh}.result.outcome {} is not one of {outcomes_repr}",
                    outcome_val.map_or("None".into(), py_repr)
                ));
                continue;
            }
        };

        // Tier honesty: the evidence a tier claims must be present.
        let ladder: &[Value] = match e.get("proof_ladder") {
            Some(Value::Array(a)) => a,
            _ => &[],
        };
        let evidence = match e.get("evidence") {
            Some(Value::Object(m)) => Some(m),
            _ => None,
        };
        match tier {
            Some("ActuallyProven") => {
                if ladder.is_empty() {
                    v.push(format!("{wh} claims ActuallyProven with an empty proof ladder"));
                }
                for (j, rung) in ladder.iter().enumerate() {
                    let text = |key: &str| match rung {
                        Value::Object(m) => match m.get(key) {
                            Some(Value::String(s)) if !blank(s) => true,
                            _ => false,
                        },
                        _ => false,
                    };
                    if !text("theorem") {
                        v.push(format!("{wh}.proof_ladder[{j}] has no cited theorem"));
                    }
                    if !text("statement") {
                        v.push(format!("{wh}.proof_ladder[{j}] has no stated proposition"));
                    }
                }
            }
            Some("ProvisionallyProven") => {
                if !truthy(evidence.and_then(|m| m.get("framework_safety"))) {
                    v.push(format!("{wh} claims ProvisionallyProven without framework_safety"));
                }
                if !truthy(evidence.and_then(|m| m.get("test_safety"))) {
                    v.push(format!("{wh} claims ProvisionallyProven without test_safety"));
                }
            }
            _ => {
                if !ladder.is_empty() {
                    v.push(format!("{wh} is Unproven but carries a non-empty proof ladder"));
                }
            }
        }

        // Fixture doctrine: every test states its position; debt is named.
        let ob_val = e.get("fixture_obligation");
        let ob = match ob_val {
            Some(Value::String(s)) if FIXTURE_OBLIGATIONS.contains(&s.as_str()) => Some(s.as_str()),
            _ => None,
        };
        if ob.is_none() {
            v.push(format!(
                "{wh}.fixture_obligation {} is not one of {obligations_repr}",
                ob_val.map_or("None".into(), py_repr)
            ));
        }
        if ob == Some("FixtureDebt") && !truthy(e.get("fixture_debt_ref")) {
            v.push(format!("{wh} is FixtureDebt without a fixture_debt_ref"));
        }
        if ob == Some("Fixtures") {
            let pair_ok = match e.get("fixtures") {
                Some(Value::Object(p)) => truthy(p.get("silence")) && truthy(p.get("firing")),
                _ => false,
            };
            if !pair_ok {
                v.push(format!("{wh} is Fixtures without a silence/firing pair"));
            }
        }

        // Counting: debt-marked entries are not tests in any ledger (B.4).
        if ob == Some("FixtureDebt") {
            debt += 1;
            continue;
        }
        match outcome {
            "passed" => {
                passed += 1;
                if truthy(e.get("category")) && truthy(e.get("aspect")) {
                    if let (Some(Value::String(c)), Some(Value::String(a))) = (e.get("category"), e.get("aspect")) {
                        passed_cells.insert((c.clone(), a.clone()));
                    }
                }
            }
            "failed" => failed += 1,
            "error" => errored += 1,
            _ => skipped += 1,
        }
    }

    let derived = passed_cells.len() as i64;
    let Some(Value::Object(summary)) = doc.get("summary") else {
        v.push("report has no summary object".into());
        return Ok((v, derived));
    };

    let counter_keys = [
        "covered_cells", "passed", "failed", "errors", "skipped", "total", "lattice_covered",
        "cat_aspect_cells", "actually_proven", "provisionally_proven", "unproven",
    ];
    for key in counter_keys {
        if !non_negative_int(summary.get(key)) {
            v.push(format!("summary.{key} must be a non-negative integer"));
        }
    }

    let shown = |key: &str| summary.get(key).map_or("None".into(), py_str);
    if !eq_int(summary.get("covered_cells"), derived) {
        v.push(format!(
            "summary.covered_cells={} but only {derived} (category x aspect) cell(s) are backed by an entry that ran and passed",
            shown("covered_cells")
        ));
    }
    for (key, got, label) in [
        ("passed", passed, "passed"),
        ("failed", failed, "failed"),
        ("errors", errored, "errored"),
        ("skipped", skipped, "skipped"),
    ] {
        if !eq_int(summary.get(key), got) {
            v.push(format!("summary.{key}={} but {got} {label}", shown(key)));
        }
    }
    let non_debt = entries.len() as i64 - debt;
    if !eq_int(summary.get("total"), non_debt) {
        v.push(format!(
            "summary.total={} but {non_debt} non-debt entries (debt-marked entries are not counted)",
            shown("total")
        ));
    }
    for (idx, (_, key)) in TIER_SUMMARY_KEY.iter().enumerate() {
        if !eq_int(summary.get(*key), tier_counts[idx]) {
            v.push(format!("summary.{key}={} but {}", shown(key), tier_counts[idx]));
        }
    }
    if !eq_int(summary.get("lattice_covered"), derived) {
        v.push(format!(
            "summary.lattice_covered={} but only {derived} cell(s) are backed by an entry that ran and passed",
            shown("lattice_covered")
        ));
    }

    Ok((v, derived))
}

// ════════════════════════════════════════════════════════════════════════════
// cicd-squabbler
// ════════════════════════════════════════════════════════════════════════════

fn kind(run: Option<&Value>) -> Result<&'static str, ContractError> {
    match run {
        Some(Value::String(s)) => run_kind(s).ok_or_else(|| ContractError(format!("unrecognised check run {}", py_repr(&Value::String(s.clone()))))),
        other => cerr(format!("unrecognised check run {}", other.map_or("None".into(), py_repr))),
    }
}

/// The engine's Gate::evaluate verdict over realised runs.
fn evaluate_gate(kinds: &[&str]) -> &'static str {
    if kinds.is_empty() {
        return "Blocked"; // an empty requirement set is unprotected, not won
    }
    if kinds.iter().all(|k| matches!(*k, "Passed" | "Skipped")) {
        return "Green";
    }
    if kinds.iter().any(|k| *k == "Failed") {
        return "Red";
    }
    "Blocked"
}

/// The downstream-facing predicate: a green that carries evidence and has not
/// dropped or renamed away a required context. Stricter than Green: an
/// all-Skipped gate proves nothing, and a gate missing a required context is a
/// bypass, not a win.
fn legitimate_green(required: &[String], contexts: &[&str], kinds: &[&str]) -> bool {
    if evaluate_gate(kinds) != "Green" {
        return false;
    }
    if required.is_empty() || kinds.is_empty() {
        return false;
    }
    if required.iter().any(|r| !contexts.contains(&r.as_str())) {
        return false; // a dropped or renamed-away required context
    }
    if kinds.iter().any(|k| matches!(*k, "Missing" | "Pending" | "Failed")) {
        return false;
    }
    kinds.contains(&"Passed") // no evidence-bearing green otherwise
}

/// Returns (gate_state, is_legitimate_green, evidence_free_count). Skipped and
/// neutral runs count as evidence-free.
pub fn validate_squabbler_gate(doc: &Value) -> Result<(&'static str, bool, i64), ContractError> {
    let Value::Object(doc) = doc else {
        return cerr("gate is not a JSON object");
    };
    let Some(Value::Array(required)) = doc.get("required_contexts") else {
        return cerr("gate has no 'required_contexts' array");
    };
    let Some(Value::Array(checks)) = doc.get("checks") else {
        return cerr("gate has no 'checks' array");
    };
    let mut required_names: Vec<String> = Vec::new();
    for context in required {
        match context {
            Value::String(s) if !blank(s) => required_names.push(s.clone()),
            _ => return cerr("required contexts must be non-empty strings"),
        }
    }
    let mut contexts: Vec<&str> = Vec::new();
    let mut kinds: Vec<&'static str> = Vec::new();
    for c in checks {
        match c.get("required_context") {
            Some(Value::String(s)) if !blank(s) => contexts.push(s),
            _ => return cerr("a check is missing required_context"),
        }
        kinds.push(kind(c.get("run"))?); // structural check
    }
    let free = kinds.iter().filter(|k| **k == "Skipped").count() as i64;
    Ok((evaluate_gate(&kinds), legitimate_green(&required_names, &contexts, &kinds), free))
}

// ════════════════════════════════════════════════════════════════════════════
// case runner
// ════════════════════════════════════════════════════════════════════════════

/// Read a UTF-8 JSON file. A missing, unreadable or unparseable file means no
/// check could be performed.
pub fn load(path: &Path) -> Result<Value, ContractError> {
    if !path.is_file() {
        return cerr(format!("missing file: {}", path.display()));
    }
    let raw = std::fs::read_to_string(path)
        .map_err(|e| ContractError(format!("cannot read {}: {e}", path.display())))?;
    serde_json::from_str(&raw).map_err(|e| ContractError(format!("unparseable JSON in {}: {e}", path.display())))
}

fn is_proven(surface: &str) -> bool {
    surface == "proven-tests"
}

/// Run the named surface's fixture cases (cases.json under `root/surface`) and
/// print their verdicts. Returns 1 for an unmet expectation or a fixture that
/// could not be checked, else 0.
pub fn run_surface(root: &Path, surface: &str, out: &mut dyn Write) -> Result<i32, ContractError> {
    let surface_dir = root.join(surface);
    let cases_doc = load(&surface_dir.join("cases.json"))?;
    let cases = match cases_doc.get("cases") {
        Some(Value::Array(a)) => a,
        _ => return cerr(format!("{}: no 'cases' array", surface_dir.join("cases.json").display())),
    };
    let (mut failures, mut ran) = (0i64, 0i64);
    for case in cases {
        let (Some(id), Some(Value::String(fixture)), Some(Value::Object(expect))) =
            (case.get("id"), case.get("fixture"), case.get("expect"))
        else {
            return cerr(format!("{}: a case lacks id, fixture or expect", surface_dir.join("cases.json").display()));
        };
        let id = py_str(id);
        let mut violations: Vec<String> = Vec::new();
        let outcome = (|| -> Result<Map<String, Value>, ContractError> {
            let doc = load(&surface_dir.join(fixture))?;
            let mut actual = Map::new();
            if is_proven(surface) {
                let (viol, derived) = validate_proven_report(&doc)?;
                actual.insert("valid".into(), json!(viol.is_empty()));
                actual.insert("derived_covered_cells".into(), json!(derived));
                violations = viol;
            } else {
                let (state, legit, free) = validate_squabbler_gate(&doc)?;
                actual.insert("gate_state".into(), json!(state));
                actual.insert("legitimate_green".into(), json!(legit));
                actual.insert("evidence_free".into(), json!(free));
            }
            Ok(actual)
        })();
        let actual = match outcome {
            Ok(a) => a,
            Err(exc) => {
                let _ = writeln!(out, "  FAIL {id}: no check performed \u{2014} {exc}");
                failures += 1;
                continue;
            }
        };
        ran += 1;
        let mut bad: Vec<String> = Vec::new();
        for (key, want) in expect {
            let got = actual.get(key);
            if got != Some(want) && !(got.is_none() && want.is_null()) {
                bad.push(format!("{key}={} (expected {})", got.map_or("None".into(), py_repr), py_repr(want)));
            }
        }
        if !bad.is_empty() {
            failures += 1;
            let _ = writeln!(out, "  FAIL {id}: {}", bad.join("; "));
        } else {
            let shown: Vec<String> = expect.iter().map(|(k, v)| format!("{k}={}", py_repr(v))).collect();
            let _ = writeln!(out, "  ok   {id}: {}", shown.join(", "));
        }
        if is_proven(surface) && truthy(case.get("expect_invalid_reason")) {
            let reason = py_str(case.get("expect_invalid_reason").unwrap_or(&Value::Null));
            if violations.is_empty() {
                let _ = writeln!(out, "  FAIL {id}: expected invalidity but report validated");
                failures += 1;
            } else if !violations.iter().any(|t| t.contains(&reason)) {
                let _ = writeln!(
                    out,
                    "  FAIL {id}: invalid for the wrong reason; wanted a violation mentioning {}",
                    py_repr(&Value::String(reason))
                );
                failures += 1;
            }
        }
    }
    let _ = writeln!(out, "{surface}: {}/{ran} case(s) passed", ran - failures);
    Ok(if failures > 0 { 1 } else { 0 })
}

/// Print a file's report violations or gate verdict and return its status:
/// 1 for report violations, 2 when no check was possible, else 0. An
/// illegitimate green alone does not change the status.
pub fn validate_file(path: &Path, surface: &str, out: &mut dyn Write) -> Result<i32, ContractError> {
    let doc = load(path)?;
    let (violations, derived): (Vec<String>, Option<i64>) = if is_proven(surface) {
        match validate_proven_report(&doc) {
            Ok((v, d)) => (v, Some(d)),
            Err(exc) => {
                let _ = writeln!(out, "NO CHECK PERFORMED: {exc}");
                return Ok(2);
            }
        }
    } else {
        match validate_squabbler_gate(&doc) {
            Ok((state, legit, free)) => {
                let _ = writeln!(
                    out,
                    "gate_state={state} legitimate_green={} evidence_free={free}",
                    if legit { "True" } else { "False" }
                );
                (Vec::new(), None)
            }
            Err(exc) => {
                let _ = writeln!(out, "NO CHECK PERFORMED: {exc}");
                return Ok(2);
            }
        }
    };
    if !violations.is_empty() {
        let _ = writeln!(out, "NOT CONFORMANT:");
        for v in &violations {
            let _ = writeln!(out, "  - {v}");
        }
        if let Some(d) = derived {
            let _ = writeln!(out, "derived_covered_cells={d}");
        }
        return Ok(1);
    }
    let _ = writeln!(out, "CONFORMANT");
    if let Some(d) = derived {
        let _ = writeln!(out, "derived_covered_cells={d}");
    }
    Ok(0)
}

fn is_surface(s: &str) -> bool {
    s == "proven-tests" || s == "cicd-squabbler"
}

/// Where the surface directories (`proven-tests/`, `cicd-squabbler/`) live:
/// `PROVEN_CONTRACT_ROOT` if set, else `integrations/contract` found from this
/// crate's manifest directory at build time.
pub fn default_root() -> PathBuf {
    if let Some(p) = std::env::var_os("PROVEN_CONTRACT_ROOT") {
        return PathBuf::from(p);
    }
    let manifest = Path::new(env!("CARGO_MANIFEST_DIR"));
    manifest.ancestors().nth(4).map(Path::to_path_buf).unwrap_or_else(|| manifest.to_path_buf())
}

/// Dispatch checker arguments (without the program name) and return a status.
/// A structural problem becomes status 2. Anything not understood is status 2
/// and never runs a different surface.
pub fn check_main(args: &[String], root: &Path, out: &mut dyn Write) -> i32 {
    let result = match args {
        [surface] if is_surface(surface) => run_surface(root, surface, out),
        [cmd, path, surface] if cmd == "validate-file" && is_surface(surface) => validate_file(Path::new(path), surface, out),
        _ => {
            let _ = writeln!(out, "Downstream evidence contract checker");
            let _ = writeln!(out, "\nusage: proven-contract <proven-tests|cicd-squabbler>");
            let _ = writeln!(out, "       proven-contract validate-file <path> <proven-tests|cicd-squabbler>");
            let _ = writeln!(out, "       proven-contract emit-report <tests.json> <report.json>");
            return 2;
        }
    };
    match result {
        Ok(code) => code,
        Err(exc) => {
            let _ = writeln!(out, "NO CHECK PERFORMED: {exc}");
            2
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// emit-report: the producer half (was emit_report.py)
// ════════════════════════════════════════════════════════════════════════════
//
// Turn a flat list of executed test results into a schema_version-2 run report.
//
//   * a downstream repository cannot claim ActuallyProven; that tier needs an
//     Idris2 proof ladder checked by the type checker. Refused, not downgraded.
//   * ProvisionallyProven requires its framework-safety and test-safety
//     certificates.
//   * coverage is DERIVED from entries whose outcome is "passed"; it is never
//     taken from the input.
//
// EXIT CODES: 0 written; 1 a test fact is dishonest or malformed; 2 the input
// could not be read or parsed (NO CHECK WAS PERFORMED).

const EMIT_TIERS: [&str; 2] = ["Unproven", "ProvisionallyProven"];

/// A failed emit: the message and the exit code it carries.
#[derive(Debug)]
pub struct EmitError {
    pub message: String,
    pub code: i32,
}

fn efail<T>(message: impl Into<String>, code: i32) -> Result<T, EmitError> {
    Err(EmitError { message: message.into(), code })
}

/// Python's `int(value)` for a JSON value: ints, truncated floats, bools and
/// numeric strings convert; anything else is an error.
fn py_int(v: &Value) -> Result<i64, String> {
    match v {
        Value::Bool(b) => Ok(i64::from(*b)),
        Value::Number(n) => match n.as_i64() {
            Some(i) => Ok(i),
            None => match n.as_f64() {
                Some(f) if f.is_finite() && f.abs() < 9.2e18 => Ok(f.trunc() as i64),
                _ => Err(format!("cannot convert {} to an integer", py_repr(v))),
            },
        },
        Value::String(s) => {
            let t = s.trim_matches(py_space);
            let (sign, digits) = match t.strip_prefix('-') {
                Some(d) => (-1i64, d),
                None => (1, t.strip_prefix('+').unwrap_or(t)),
            };
            let valid = !digits.is_empty()
                && !digits.starts_with('_')
                && !digits.ends_with('_')
                && !digits.contains("__")
                && digits.chars().all(|c| c.is_ascii_digit() || c == '_');
            if !valid {
                return Err(format!("invalid literal for int(): {}", py_repr(v)));
            }
            let clean: String = digits.chars().filter(|c| *c != '_').collect();
            clean.parse::<i64>().map(|n| n * sign).map_err(|_| format!("integer out of range: {}", py_repr(v)))
        }
        other => Err(format!("int() argument must be a string or a number, not {}", py_repr(other))),
    }
}

/// Build a schema_version-2 report from a flat tests array without running
/// tests. Coverage counts distinct truthy category/aspect pairs on passed,
/// non-debt entries; FixtureDebt entries count towards tier totals only.
pub fn emit(input_doc: &Value) -> Result<Value, EmitError> {
    let Value::Object(input) = input_doc else {
        return efail("input is not a JSON object", 2);
    };
    let Some(Value::Array(tests)) = input.get("tests") else {
        return efail("input has no 'tests' array", 2);
    };

    let mut entries: Vec<Value> = Vec::new();
    let mut covered: BTreeSet<(String, String)> = BTreeSet::new();
    let (mut passed, mut failed, mut errors, mut skipped, mut debt) = (0i64, 0i64, 0i64, 0i64, 0i64);
    let (proven, mut provisional, mut unproven) = (0i64, 0i64, 0i64);
    let tiers_repr = tuple_repr(&EMIT_TIERS);
    let outcomes_repr = tuple_repr(&OUTCOMES);
    let obligations_repr = tuple_repr(&FIXTURE_OBLIGATIONS);

    for (i, t) in tests.iter().enumerate() {
        let wh = format!("tests[{i}]");
        let Value::Object(t) = t else {
            return efail(format!("{wh} is not an object"), 1);
        };
        let tier_val = t.get("tier");
        let tier = match tier_val {
            Some(Value::String(s)) if EMIT_TIERS.contains(&s.as_str()) => s.as_str(),
            _ => {
                return efail(
                    format!(
                        "{wh}.tier {}: a downstream repository may only claim {tiers_repr}; ActuallyProven needs an Idris2 proof ladder",
                        tier_val.map_or("None".into(), py_repr)
                    ),
                    1,
                )
            }
        };
        let outcome_val = t.get("outcome");
        let outcome = match outcome_val {
            Some(Value::String(s)) if OUTCOMES.contains(&s.as_str()) => s.as_str(),
            _ => {
                return efail(
                    format!("{wh}.outcome {} is not one of {outcomes_repr}", outcome_val.map_or("None".into(), py_repr)),
                    1,
                )
            }
        };
        let ob_val = t.get("fixture_obligation").cloned().unwrap_or_else(|| json!("Fixtures"));
        let ob = match &ob_val {
            Value::String(s) if FIXTURE_OBLIGATIONS.contains(&s.as_str()) => s.as_str(),
            other => return efail(format!("{wh}.fixture_obligation {} is not one of {obligations_repr}", py_repr(other)), 1),
        };
        if ob == "FixtureDebt" && !truthy(t.get("fixture_debt_ref")) {
            return efail(format!("{wh} is FixtureDebt without a fixture_debt_ref"), 1);
        }

        let mut evidence = Map::new();
        if tier == "ProvisionallyProven" {
            if !truthy(t.get("framework_safety")) || !truthy(t.get("test_safety")) {
                return efail(format!("{wh} claims ProvisionallyProven without its certificates"), 1);
            }
            evidence.insert("framework_safety".into(), t["framework_safety"].clone());
            evidence.insert("test_safety".into(), t["test_safety"].clone());
        }

        let mut result = Map::new();
        result.insert("outcome".into(), json!(outcome));
        if outcome != "passed" && truthy(t.get("message")) {
            result.insert("message".into(), t["message"].clone());
        }

        let get_or = |key: &str, default: Value| t.get(key).cloned().unwrap_or(default);
        let line = match t.get("line") {
            None => 0,
            Some(v) => py_int(v).map_err(|m| EmitError { message: format!("{wh}.line: {m}"), code: 1 })?,
        };
        let mut test_id = Map::new();
        test_id.insert("module_path".into(), get_or("module", json!("")));
        test_id.insert("test_name".into(), get_or("name", json!("")));
        test_id.insert("line_number".into(), json!(line));

        let mut entry = Map::new();
        entry.insert("test_id".into(), Value::Object(test_id));
        entry.insert("category".into(), get_or("category", Value::Null));
        entry.insert("aspect".into(), get_or("aspect", Value::Null));
        entry.insert("typesafe_category".into(), get_or("typesafe_category", Value::Null));
        entry.insert("provenance".into(), json!(tier));
        entry.insert("evidence".into(), Value::Object(evidence));
        entry.insert("proof_ladder".into(), json!([]));
        entry.insert("result".into(), Value::Object(result));
        entry.insert("fixture_obligation".into(), json!(ob));
        if truthy(t.get("oracle_provenance")) {
            entry.insert("oracle_provenance".into(), t["oracle_provenance"].clone());
        }
        if ob == "Fixtures" {
            if !truthy(t.get("silence")) || !truthy(t.get("firing")) {
                return efail(format!("{wh} is Fixtures without a silence/firing pair"), 1);
            }
            let mut pair = Map::new();
            pair.insert("silence".into(), t["silence"].clone());
            pair.insert("firing".into(), t["firing"].clone());
            entry.insert("fixtures".into(), Value::Object(pair));
        }
        if let Some(d) = t.get("duration_ms").filter(|d| !d.is_null()) {
            let ms = py_int(d).map_err(|m| EmitError { message: format!("{wh}.duration_ms: {m}"), code: 1 })?;
            entry.insert("duration_ms".into(), json!(ms));
        }

        match tier {
            "ProvisionallyProven" => provisional += 1,
            _ => unproven += 1,
        }
        if ob == "FixtureDebt" {
            debt += 1;
            entry.insert("fixture_debt_ref".into(), t["fixture_debt_ref"].clone());
        } else {
            match outcome {
                "passed" => passed += 1,
                "failed" => failed += 1,
                "error" => errors += 1,
                _ => skipped += 1,
            }
            if outcome == "passed" && truthy(t.get("category")) && truthy(t.get("aspect")) {
                match (&t["category"], &t["aspect"]) {
                    (Value::Array(_) | Value::Object(_), _) | (_, Value::Array(_) | Value::Object(_)) => {
                        return efail(format!("{wh}: category and aspect must be hashable scalars"), 1)
                    }
                    (c, a) => {
                        covered.insert((py_repr(c), py_repr(a)));
                    }
                }
            }
        }
        entries.push(Value::Object(entry));
    }

    let covered_cells = covered.len() as i64;
    let mut summary = Map::new();
    summary.insert("passed".into(), json!(passed));
    summary.insert("failed".into(), json!(failed));
    summary.insert("errors".into(), json!(errors));
    summary.insert("skipped".into(), json!(skipped));
    summary.insert("total".into(), json!(entries.len() as i64 - debt));
    summary.insert("actually_proven".into(), json!(proven));
    summary.insert("provisionally_proven".into(), json!(provisional));
    summary.insert("unproven".into(), json!(unproven));
    summary.insert("covered_cells".into(), json!(covered_cells));
    summary.insert("cat_aspect_cells".into(), input.get("cat_aspect_cells").cloned().unwrap_or_else(|| json!(238)));
    summary.insert("lattice_covered".into(), json!(covered_cells));

    let mut report = Map::new();
    report.insert("schema_version".into(), json!(2));
    report.insert("suite".into(), input.get("suite").cloned().unwrap_or_else(|| json!("proven-tests-downstream")));
    report.insert("generated_at".into(), input.get("generated_at").cloned().unwrap_or_else(|| json!("")));
    report.insert("toolchain".into(), input.get("toolchain").cloned().unwrap_or_else(|| json!({})));
    report.insert("summary".into(), Value::Object(summary));
    report.insert("entries".into(), Value::Array(entries));
    Ok(Value::Object(report))
}

/// Pretty-print like Python's `json.dump(indent=2)`: two-space indent and
/// ASCII-only output (non-ASCII characters become \uXXXX escapes).
pub fn to_python_json(value: &Value) -> String {
    let text = serde_json::to_string_pretty(value).unwrap_or_default();
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        if c.is_ascii() {
            out.push(c);
        } else {
            let mut units = [0u16; 2];
            for u in c.encode_utf16(&mut units) {
                out.push_str(&format!("\\u{u:04x}"));
            }
        }
    }
    out
}

/// `emit-report <tests.json> <report.json>`: read runner facts, overwrite a
/// report. Messages go to `err`, the success line to `out`.
pub fn emit_main(args: &[String], out: &mut dyn Write, err: &mut dyn Write) -> i32 {
    let [in_path, out_path] = args else {
        let _ = writeln!(err, "usage: proven-contract emit-report <tests.json> <report.json>");
        return 2;
    };
    let fail = |err: &mut dyn Write, msg: String, code: i32| {
        let _ = writeln!(err, "emit_report: {msg}");
        code
    };
    let raw = match std::fs::read_to_string(in_path) {
        Ok(r) => r,
        Err(e) => return fail(err, format!("cannot read {in_path}: {e}"), 2),
    };
    let doc: Value = match serde_json::from_str(&raw) {
        Ok(d) => d,
        Err(e) => return fail(err, format!("{in_path} is not valid JSON: {e}"), 2),
    };
    let report = match emit(&doc) {
        Ok(r) => r,
        Err(e) => return fail(err, e.message, e.code),
    };
    if let Err(e) = std::fs::write(out_path, to_python_json(&report) + "\n") {
        return fail(err, format!("cannot write {out_path}: {e}"), 1);
    }
    let s = &report["summary"];
    let _ = writeln!(
        out,
        "wrote {out_path}: {}/{} passed, {} covered cell(s)",
        s["passed"], s["total"], s["covered_cells"]
    );
    0
}
