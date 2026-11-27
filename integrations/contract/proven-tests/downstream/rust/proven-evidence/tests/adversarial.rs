// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Malformed evidence must be rejected, never crash or acquire a green verdict.
// Rust port of the former test_check_contract.py / test_adversarial_contract.py.

use proven_evidence::contract::{self, main_with, validate_proven_report, ContractError};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};

fn root() -> PathBuf {
    contract::default_root()
}

fn clean() -> Value {
    let p = root().join("proven-tests/fixtures/report-valid-mixed.json");
    serde_json::from_str(&std::fs::read_to_string(p).expect("fixture")).expect("json")
}

/// Run validate-file on a document through the CLI dispatcher.
fn status(doc: &Value, surface: &str) -> i32 {
    static N: AtomicUsize = AtomicUsize::new(0);
    let dir = std::env::temp_dir().join(format!("pe-adv-{}-{}", std::process::id(), N.fetch_add(1, Ordering::Relaxed)));
    std::fs::create_dir_all(&dir).expect("tmp");
    let path = dir.join("report.json");
    std::fs::write(&path, doc.to_string()).expect("write");
    let args = ["validate-file".to_string(), path.display().to_string(), surface.to_string()];
    main_with(&root(), &args)
}

#[test]
fn both_surfaces_pass_their_fixture_cases() {
    assert_eq!(main_with(&root(), &["proven-tests".into()]), 0);
    assert_eq!(main_with(&root(), &["cicd-squabbler".into()]), 0);
}

#[test]
fn positive_and_boolean_counter_controls() {
    let c = clean();
    assert_eq!(status(&c, "proven-tests"), 0);
    for (key, value) in c["summary"].as_object().expect("summary") {
        if value.is_i64() || value.is_u64() {
            let mut doc = c.clone();
            doc["summary"][key] = json!(value.as_i64() != Some(0));
            assert_ne!(status(&doc, "proven-tests"), 0, "counter {key}");
        }
    }
}

#[test]
fn proof_rung_requires_nonempty_strings() {
    let mut doc = clean();
    doc["entries"][0]["provenance"] = json!("ActuallyProven");
    doc["entries"][0]["proof_ladder"] =
        json!([{"theorem": "Fixture.identity", "statement": "For every x, identity x = x"}]);
    let bump = |d: &mut Value, k: &str, by: i64| {
        let cur = d["summary"][k].as_i64().expect("int");
        d["summary"][k] = json!(cur + by);
    };
    bump(&mut doc, "actually_proven", 1);
    bump(&mut doc, "provisionally_proven", -1);
    assert_eq!(status(&doc, "proven-tests"), 0);
    for field in ["theorem", "statement"] {
        for value in [json!(true), json!(7), Value::Null, json!(["claim"]), json!({"claim": 1}), json!(""), json!("  ")] {
            let mut mutant = doc.clone();
            mutant["entries"][0]["proof_ladder"][0][field] = value.clone();
            assert_ne!(status(&mutant, "proven-tests"), 0, "{field}={value}");
        }
    }
}

#[test]
fn bounded_json_shape_robustness() {
    // Robustness only: a mutation to optional metadata can remain valid. Every
    // mutant must yield a verdict or an explicit ContractError, never a panic.
    let base = clean();
    let mut paths: Vec<Vec<String>> = Vec::new();
    fn walk(v: &Value, path: Vec<String>, out: &mut Vec<Vec<String>>) {
        out.push(path.clone());
        match v {
            Value::Object(m) => m.iter().for_each(|(k, c)| {
                let mut p = path.clone();
                p.push(k.clone());
                walk(c, p, out);
            }),
            Value::Array(a) => a.iter().enumerate().for_each(|(i, c)| {
                let mut p = path.clone();
                p.push(i.to_string());
                walk(c, p, out);
            }),
            _ => {}
        }
    }
    walk(&base, vec![], &mut paths);
    let values = [Value::Null, json!(true), json!(false), json!(0), json!(-1), json!(1.5), json!(""),
                  json!("  "), json!([]), json!({}), json!(["x"]), json!({"x": true})];
    let mut state: u64 = 1371;
    let mut next = |n: usize| {
        state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        ((state >> 33) as usize) % n
    };
    for _ in 0..2000 {
        let path = &paths[next(paths.len())];
        let value = values[next(values.len())].clone();
        let mut doc = base.clone();
        if path.is_empty() {
            doc = value;
        } else {
            let mut cur = &mut doc;
            for key in &path[..path.len() - 1] {
                cur = match cur {
                    Value::Array(a) => &mut a[key.parse::<usize>().expect("index")],
                    other => &mut other[key.as_str()],
                };
            }
            match cur {
                Value::Array(a) => a[path[path.len() - 1].parse::<usize>().expect("index")] = value,
                other => other[path[path.len() - 1].as_str()] = value,
            }
        }
        match validate_proven_report(&doc) {
            Ok(_) | Err(ContractError(_)) => {}
        }
    }
}

#[test]
fn malformed_nested_types_are_no_check_performed() {
    for field in ["evidence", "proof_ladder", "category", "aspect"] {
        for value in [json!(true), json!(12), json!(["unexpected"]), json!({"unexpected": 1})] {
            if (field == "evidence" && value.is_object()) || (field == "proof_ladder" && value.is_array()) {
                continue;
            }
            let mut doc = clean();
            doc["entries"][0][field] = value.clone();
            assert_eq!(status(&doc, "proven-tests"), 2, "{field}={value}");
        }
    }
}

#[test]
fn malformed_contexts_are_no_check_performed() {
    for value in [json!(true), json!(12), json!(["nested"]), json!({"nested": 1}), json!(""), Value::Null] {
        for which in ["required", "check"] {
            let mut doc = json!({"required_contexts": ["build"],
                                 "checks": [{"required_context": "build", "run": "passed"}]});
            if which == "required" {
                doc["required_contexts"] = json!([value.clone()]);
            } else {
                doc["checks"][0]["required_context"] = value.clone();
            }
            assert_eq!(status(&doc, "cicd-squabbler"), 2, "{which}={value}");
        }
    }
}

#[test]
fn invalid_cli_never_dispatches_a_different_surface() {
    assert_eq!(status(&json!({"required_contexts": [], "checks": []}), "typo"), 2);
    assert_eq!(main_with(&root(), &[]), 2);
    assert_eq!(main_with(&root(), &["proven-tests".into(), "ignored".into()]), 2);
}

#[test]
fn missing_and_unparseable_files_are_no_check_performed() {
    let dir = std::env::temp_dir().join(format!("pe-missing-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("tmp");
    let path = dir.join("report.json");
    let _ = std::fs::remove_file(&path);
    let args = |p: &PathBuf| ["validate-file".to_string(), p.display().to_string(), "proven-tests".to_string()];
    assert_eq!(main_with(&root(), &args(&path)), 2);
    std::fs::write(&path, "{").expect("write");
    assert_eq!(main_with(&root(), &args(&path)), 2);
    // A surface directory with a missing or unparseable cases.json.
    let surface = dir.join("proven-tests");
    std::fs::create_dir_all(&surface).expect("tmp");
    assert_eq!(main_with(&dir, &["proven-tests".into()]), 2);
    std::fs::write(surface.join("cases.json"), "{").expect("write");
    assert_eq!(main_with(&dir, &["proven-tests".into()]), 2);
}

#[test]
fn emit_refuses_dishonest_tiers_and_derives_coverage() {
    use proven_evidence::emit::emit;
    let bad = json!({"tests": [{"tier": "ActuallyProven", "outcome": "passed"}]});
    assert_eq!(emit(&bad).expect_err("refused").code, 1);
    assert_eq!(emit(&json!([])).expect_err("refused").code, 2);
    let ok = json!({"tests": [{
        "module": "m", "name": "n", "category": "Unit", "aspect": "Functionality",
        "tier": "Unproven", "outcome": "passed", "fixture_obligation": "Fixtures",
        "silence": {"a": 1}, "firing": {"b": 2}}]});
    let report = emit(&ok).expect("report");
    assert_eq!(report["summary"]["covered_cells"], 1);
    assert!(validate_proven_report(&report).expect("structure").0.is_empty());
}
