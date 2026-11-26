// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Producer half of the downstream contract: turn a flat list of executed test
// results into a schema_version-2 run report. Honesty rules:
//   * a downstream repository cannot claim ActuallyProven (needs an Idris2
//     proof ladder) — refused, not downgraded;
//   * ProvisionallyProven requires both safety certificates;
//   * coverage is DERIVED from passed, non-debt entries, never taken from input.

use serde_json::{json, Map, Value};
use std::collections::BTreeSet;

/// Why emitting failed. `NoCheck` maps to exit 2, `Dishonest` to exit 1.
#[derive(Debug, PartialEq, Eq)]
pub enum EmitError {
    NoCheck(String),
    Dishonest(String),
}

fn truthy(v: Option<&Value>) -> bool {
    v.is_some_and(crate::is_truthy)
}

fn str_of<'a>(t: &'a Map<String, Value>, k: &str) -> Option<&'a str> {
    t.get(k).and_then(Value::as_str)
}

fn int_of(v: Option<&Value>) -> Result<i64, EmitError> {
    match v {
        None | Some(Value::Null) => Ok(0),
        Some(Value::Bool(b)) => Ok(*b as i64),
        Some(Value::Number(n)) => n
            .as_i64()
            .or_else(|| n.as_f64().map(|f| f.trunc() as i64))
            .ok_or_else(|| EmitError::Dishonest("integer field out of range".into())),
        Some(Value::String(s)) => s
            .trim()
            .parse::<i64>()
            .map_err(|_| EmitError::Dishonest(format!("not an integer: {s:?}"))),
        Some(_) => Err(EmitError::Dishonest("integer field has the wrong type".into())),
    }
}

/// Build the report. Never runs tests.
pub fn emit(input: &Value) -> Result<Value, EmitError> {
    let doc = input
        .as_object()
        .ok_or_else(|| EmitError::NoCheck("input is not a JSON object".into()))?;
    let tests = doc
        .get("tests")
        .and_then(Value::as_array)
        .ok_or_else(|| EmitError::NoCheck("input has no 'tests' array".into()))?;

    let bad = |m: String| Err(EmitError::Dishonest(m));
    let mut entries: Vec<Value> = Vec::new();
    let mut covered: BTreeSet<(String, String)> = BTreeSet::new();
    let (mut passed, mut failed, mut errored, mut skipped) = (0i64, 0i64, 0i64, 0i64);
    let (mut t_prov, mut t_unproven, mut debt) = (0i64, 0i64, 0i64);

    for (i, tv) in tests.iter().enumerate() {
        let w = format!("tests[{i}]");
        let Some(t) = tv.as_object() else {
            return bad(format!("{w} is not an object"));
        };
        let tier = str_of(t, "tier");
        if !matches!(tier, Some("Unproven" | "ProvisionallyProven")) {
            return bad(format!(
                "{w}.tier {:?}: a downstream repository may only claim \
                 (\"Unproven\", \"ProvisionallyProven\"); ActuallyProven needs an Idris2 proof ladder",
                t.get("tier")
            ));
        }
        let tier = tier.unwrap_or_default();
        let outcome = str_of(t, "outcome").unwrap_or_default();
        if !crate::OUTCOMES.contains(&outcome) {
            return bad(format!("{w}.outcome {:?} is not one of {:?}", t.get("outcome"), crate::OUTCOMES));
        }
        let ob = match t.get("fixture_obligation") {
            None => "Fixtures",
            Some(v) => v.as_str().unwrap_or(""),
        };
        if !crate::FIXTURE_OBLIGATIONS.contains(&ob) {
            return bad(format!("{w}.fixture_obligation {ob:?} is not one of {:?}", crate::FIXTURE_OBLIGATIONS));
        }
        if ob == "FixtureDebt" && !truthy(t.get("fixture_debt_ref")) {
            return bad(format!("{w} is FixtureDebt without a fixture_debt_ref"));
        }

        let mut evidence = Map::new();
        if tier == "ProvisionallyProven" {
            if !truthy(t.get("framework_safety")) || !truthy(t.get("test_safety")) {
                return bad(format!("{w} claims ProvisionallyProven without its certificates"));
            }
            evidence.insert("framework_safety".into(), t["framework_safety"].clone());
            evidence.insert("test_safety".into(), t["test_safety"].clone());
        }

        let mut result = Map::new();
        result.insert("outcome".into(), json!(outcome));
        if outcome != "passed" && truthy(t.get("message")) {
            result.insert("message".into(), t["message"].clone());
        }

        let mut entry = Map::new();
        entry.insert(
            "test_id".into(),
            json!({
                "module_path": t.get("module").cloned().unwrap_or(json!("")),
                "test_name": t.get("name").cloned().unwrap_or(json!("")),
                "line_number": int_of(t.get("line"))?,
            }),
        );
        entry.insert("category".into(), t.get("category").cloned().unwrap_or(Value::Null));
        entry.insert("aspect".into(), t.get("aspect").cloned().unwrap_or(Value::Null));
        entry.insert("typesafe_category".into(), t.get("typesafe_category").cloned().unwrap_or(Value::Null));
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
                return bad(format!("{w} is Fixtures without a silence/firing pair"));
            }
            entry.insert("fixtures".into(), json!({"silence": t["silence"], "firing": t["firing"]}));
        }
        if t.get("duration_ms").is_some_and(|v| !v.is_null()) {
            entry.insert("duration_ms".into(), json!(int_of(t.get("duration_ms"))?));
        }

        if tier == "ProvisionallyProven" { t_prov += 1 } else { t_unproven += 1 }
        if ob == "FixtureDebt" {
            debt += 1;
            entry.insert("fixture_debt_ref".into(), t["fixture_debt_ref"].clone());
        } else {
            match outcome {
                "passed" => passed += 1,
                "failed" => failed += 1,
                "error" => errored += 1,
                _ => skipped += 1,
            }
            if outcome == "passed" && truthy(t.get("category")) && truthy(t.get("aspect")) {
                if let (Some(c), Some(a)) = (str_of(t, "category"), str_of(t, "aspect")) {
                    covered.insert((c.to_string(), a.to_string()));
                }
            }
        }
        entries.push(Value::Object(entry));
    }

    let cells = covered.len() as i64;
    Ok(json!({
        "schema_version": 2,
        "suite": doc.get("suite").cloned().unwrap_or(json!("proven-tests-downstream")),
        "generated_at": doc.get("generated_at").cloned().unwrap_or(json!("")),
        "toolchain": doc.get("toolchain").cloned().unwrap_or(json!({})),
        "summary": {
            "passed": passed, "failed": failed, "errors": errored, "skipped": skipped,
            "total": entries.len() as i64 - debt,
            "actually_proven": 0, "provisionally_proven": t_prov, "unproven": t_unproven,
            "covered_cells": cells,
            "cat_aspect_cells": doc.get("cat_aspect_cells").cloned().unwrap_or(json!(crate::LATTICE_CELLS)),
            "lattice_covered": cells,
        },
        "entries": entries,
    }))
}
