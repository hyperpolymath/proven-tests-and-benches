// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Minimal downstream emitter (Rust port of the former emit_report.py): turn a
// flat list of executed test results into a schema_version-2 run report.
//
// Honesty rules, mirroring src/ProvenTests/Types.idr:
//   * a downstream repository cannot claim ActuallyProven. Refused, not downgraded.
//   * ProvisionallyProven requires both safety certificates.
//   * coverage is DERIVED from passed, non-debt entries, never taken from input.
//
// EXIT CODES: 0 written; 1 a test fact is dishonest or malformed; 2 the input
// could not be read or parsed (NO CHECK WAS PERFORMED).

use crate::contract::truthy;
use serde_json::{json, Map, Value};
use std::collections::BTreeSet;

const TIERS: [&str; 2] = ["Unproven", "ProvisionallyProven"];
const OUTCOMES: [&str; 4] = ["passed", "failed", "error", "skipped"];
const OBLIGATIONS: [&str; 3] = ["Fixtures", "CannotFailByDesign", "FixtureDebt"];

/// A refusal carrying the process exit code (1 dishonest/malformed, 2 unreadable).
#[derive(Debug, PartialEq, Eq)]
pub struct Refusal {
    pub code: i32,
    pub message: String,
}

fn refuse<T>(code: i32, message: impl Into<String>) -> Result<T, Refusal> {
    Err(Refusal { code, message: message.into() })
}

fn int_of(v: &Value) -> Option<i64> {
    match v {
        Value::Number(n) => n.as_i64().or_else(|| n.as_f64().map(|f| f as i64)),
        Value::String(s) => s.trim().parse().ok(),
        Value::Bool(b) => Some(i64::from(*b)),
        _ => None,
    }
}

/// Build a schema_version-2 report from a flat `tests` array without running tests.
pub fn emit(input: &Value) -> Result<Value, Refusal> {
    let Some(doc) = input.as_object() else {
        return refuse(2, "input is not a JSON object");
    };
    let Some(tests) = doc.get("tests").and_then(Value::as_array) else {
        return refuse(2, "input has no 'tests' array");
    };

    let mut entries: Vec<Value> = Vec::new();
    let mut covered: BTreeSet<(String, String)> = BTreeSet::new();
    let mut counts = [0i64; 4];
    let mut tiers = [0i64; 3]; // ActuallyProven, ProvisionallyProven, Unproven
    let mut debt = 0i64;

    for (i, t) in tests.iter().enumerate() {
        let w = format!("tests[{i}]");
        let Some(t) = t.as_object() else {
            return refuse(1, format!("{w} is not an object"));
        };
        let field = |k: &str| t.get(k).unwrap_or(&Value::Null);
        let tier = field("tier").as_str().filter(|x| TIERS.contains(x));
        let Some(tier) = tier else {
            return refuse(1, format!(
                "{w}.tier {}: a downstream repository may only claim {TIERS:?}; ActuallyProven needs an Idris2 proof ladder",
                field("tier")
            ));
        };
        let Some(outcome) = field("outcome").as_str().filter(|x| OUTCOMES.contains(x)) else {
            return refuse(1, format!("{w}.outcome {} is not one of {OUTCOMES:?}", field("outcome")));
        };
        let ob = t.get("fixture_obligation").map_or(Some("Fixtures"), Value::as_str);
        let Some(ob) = ob.filter(|x| OBLIGATIONS.contains(x)) else {
            return refuse(1, format!("{w}.fixture_obligation {} is not one of {OBLIGATIONS:?}", field("fixture_obligation")));
        };
        if ob == "FixtureDebt" && !truthy(field("fixture_debt_ref")) {
            return refuse(1, format!("{w} is FixtureDebt without a fixture_debt_ref"));
        }

        let mut evidence = Map::new();
        if tier == "ProvisionallyProven" {
            if !truthy(field("framework_safety")) || !truthy(field("test_safety")) {
                return refuse(1, format!("{w} claims ProvisionallyProven without its certificates"));
            }
            evidence.insert("framework_safety".into(), field("framework_safety").clone());
            evidence.insert("test_safety".into(), field("test_safety").clone());
        }

        let mut result = Map::new();
        result.insert("outcome".into(), json!(outcome));
        if outcome != "passed" && truthy(field("message")) {
            result.insert("message".into(), field("message").clone());
        }

        let line = match t.get("line") {
            None => 0,
            Some(v) => match int_of(v) {
                Some(n) => n,
                None => return refuse(1, format!("{w}.line is not an integer")),
            },
        };
        let mut entry = Map::new();
        entry.insert("test_id".into(), json!({
            "module_path": t.get("module").cloned().unwrap_or_else(|| json!("")),
            "test_name": t.get("name").cloned().unwrap_or_else(|| json!("")),
            "line_number": line,
        }));
        entry.insert("category".into(), field("category").clone());
        entry.insert("aspect".into(), field("aspect").clone());
        entry.insert("typesafe_category".into(), field("typesafe_category").clone());
        entry.insert("provenance".into(), json!(tier));
        entry.insert("evidence".into(), Value::Object(evidence));
        entry.insert("proof_ladder".into(), json!([]));
        entry.insert("result".into(), Value::Object(result));
        entry.insert("fixture_obligation".into(), json!(ob));
        if truthy(field("oracle_provenance")) {
            entry.insert("oracle_provenance".into(), field("oracle_provenance").clone());
        }
        if ob == "Fixtures" {
            if !truthy(field("silence")) || !truthy(field("firing")) {
                return refuse(1, format!("{w} is Fixtures without a silence/firing pair"));
            }
            entry.insert("fixtures".into(), json!({"silence": field("silence"), "firing": field("firing")}));
        }
        if !field("duration_ms").is_null() {
            match int_of(field("duration_ms")) {
                Some(n) => entry.insert("duration_ms".into(), json!(n)),
                None => return refuse(1, format!("{w}.duration_ms is not an integer")),
            };
        }

        tiers[if tier == "ProvisionallyProven" { 1 } else { 2 }] += 1;
        if ob == "FixtureDebt" {
            debt += 1;
            entry.insert("fixture_debt_ref".into(), field("fixture_debt_ref").clone());
        } else {
            counts[OUTCOMES.iter().position(|o| *o == outcome).unwrap_or(3)] += 1;
            if outcome == "passed" {
                if let (Some(c), Some(a)) = (field("category").as_str(), field("aspect").as_str()) {
                    if !c.is_empty() && !a.is_empty() {
                        covered.insert((c.to_string(), a.to_string()));
                    }
                }
            }
        }
        entries.push(Value::Object(entry));
    }

    let cells = doc.get("cat_aspect_cells").cloned().unwrap_or_else(|| json!(238));
    Ok(json!({
        "schema_version": 2,
        "suite": doc.get("suite").cloned().unwrap_or_else(|| json!("proven-tests-downstream")),
        "generated_at": doc.get("generated_at").cloned().unwrap_or_else(|| json!("")),
        "toolchain": doc.get("toolchain").cloned().unwrap_or_else(|| json!({})),
        "summary": {
            "passed": counts[0],
            "failed": counts[1],
            "errors": counts[2],
            "skipped": counts[3],
            "total": entries.len() as i64 - debt,
            "actually_proven": tiers[0],
            "provisionally_proven": tiers[1],
            "unproven": tiers[2],
            "covered_cells": covered.len(),
            "cat_aspect_cells": cells,
            "lattice_covered": covered.len(),
        },
        "entries": entries,
    }))
}
