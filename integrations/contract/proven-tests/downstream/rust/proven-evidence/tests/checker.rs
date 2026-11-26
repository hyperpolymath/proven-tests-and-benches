// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Port of the retired Python adversarial/dispatch tests: malformed
// evidence must be rejected, never crash or acquire a green verdict. Status codes
// follow the three-outcome convention (0 held, 1 not met, 2 no check performed).

use proven_evidence::runner::{run_surface, validate_file, Surface};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};

fn contract_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../..")
}

fn clean() -> Value {
    let p = contract_root().join("proven-tests/fixtures/report-valid-mixed.json");
    serde_json::from_str(&std::fs::read_to_string(p).unwrap()).unwrap()
}

fn status(doc: &Value, surface: Surface) -> i32 {
    let dir = tempdir("status");
    let path = dir.join("report.json");
    std::fs::write(&path, doc.to_string()).unwrap();
    let mut sink = Vec::new();
    validate_file(&path, surface, &mut sink).unwrap_or(2)
}

fn tempdir(tag: &str) -> PathBuf {
    use std::sync::atomic::{AtomicUsize, Ordering};
    static N: AtomicUsize = AtomicUsize::new(0);
    let d = std::env::temp_dir().join(format!("pe-{tag}-{}-{}", std::process::id(), N.fetch_add(1, Ordering::SeqCst)));
    std::fs::create_dir_all(&d).unwrap();
    d
}

#[test]
fn positive_and_boolean_counter_controls() {
    let c = clean();
    assert_eq!(status(&c, Surface::ProvenTests), 0);
    for (key, value) in c["summary"].as_object().unwrap() {
        if value.is_i64() || value.is_u64() {
            let mut doc = c.clone();
            doc["summary"][key] = json!(value.as_i64().unwrap() != 0);
            assert_ne!(status(&doc, Surface::ProvenTests), 0, "counter {key}");
        }
    }
}

#[test]
fn proof_rung_requires_nonempty_strings() {
    let mut doc = clean();
    doc["entries"][0]["provenance"] = json!("ActuallyProven");
    doc["entries"][0]["proof_ladder"] =
        json!([{"theorem": "Fixture.identity", "statement": "For every x, identity x = x"}]);
    let ap = doc["summary"]["actually_proven"].as_i64().unwrap();
    let pp = doc["summary"]["provisionally_proven"].as_i64().unwrap();
    doc["summary"]["actually_proven"] = json!(ap + 1);
    doc["summary"]["provisionally_proven"] = json!(pp - 1);
    assert_eq!(status(&doc, Surface::ProvenTests), 0);
    for field in ["theorem", "statement"] {
        for value in [json!(true), json!(7), Value::Null, json!(["claim"]), json!({"claim": 1}), json!(""), json!("  ")] {
            let mut m = doc.clone();
            m["entries"][0]["proof_ladder"][0][field] = value.clone();
            assert_ne!(status(&m, Surface::ProvenTests), 0, "{field}={value}");
        }
    }
}

#[test]
fn bounded_json_shape_robustness() {
    // Robustness only: never panic. Deterministic xorshift, 2000 mutations.
    fn paths(v: &Value, cur: &mut Vec<String>, out: &mut Vec<Vec<String>>) {
        out.push(cur.clone());
        match v {
            Value::Object(m) => for (k, c) in m { cur.push(k.clone()); paths(c, cur, out); cur.pop(); },
            Value::Array(a) => for (i, c) in a.iter().enumerate() { cur.push(i.to_string()); paths(c, cur, out); cur.pop(); },
            _ => {}
        }
    }
    let base = clean();
    let mut all = Vec::new();
    paths(&base, &mut Vec::new(), &mut all);
    let values = [Value::Null, json!(true), json!(false), json!(0), json!(-1), json!(1.5), json!(""), json!("  "),
                  json!([]), json!({}), json!(["x"]), json!({"x": true})];
    let mut s: u64 = 1371;
    let mut next = || { s ^= s << 13; s ^= s >> 7; s ^= s << 17; s };
    for _ in 0..2000 {
        let path = &all[(next() % all.len() as u64) as usize];
        let value = values[(next() % values.len() as u64) as usize].clone();
        let mut doc = base.clone();
        if path.is_empty() {
            doc = value;
        } else {
            let mut cur = &mut doc;
            for k in &path[..path.len() - 1] {
                cur = if cur.is_array() { &mut cur[k.parse::<usize>().unwrap()] } else { &mut cur[k.as_str()] };
            }
            let last = &path[path.len() - 1];
            if cur.is_array() { cur[last.parse::<usize>().unwrap()] = value } else { cur[last.as_str()] = value }
        }
        if let Ok((violations, covered)) = proven_evidence::validate_with_cells(&doc) {
            assert!(covered >= 0);
            let _ = violations;
        }
    }
}

#[test]
fn malformed_nested_types_mean_no_check() {
    for field in ["evidence", "proof_ladder", "category", "aspect"] {
        for value in [json!(true), json!(12), json!(["unexpected"]), json!({"unexpected": 1})] {
            if (field == "evidence" && value.is_object()) || (field == "proof_ladder" && value.is_array()) {
                continue;
            }
            let mut doc = clean();
            doc["entries"][0][field] = value.clone();
            assert_eq!(status(&doc, Surface::ProvenTests), 2, "{field}={value}");
        }
    }
}

#[test]
fn malformed_contexts_mean_no_check() {
    for value in [json!(true), json!(12), json!(["nested"]), json!({"nested": 1}), json!(""), Value::Null] {
        for field in ["required", "check"] {
            let mut doc = json!({"required_contexts": ["build"], "checks": [{"required_context": "build", "run": "passed"}]});
            if field == "required" { doc["required_contexts"] = json!([value.clone()]) } else { doc["checks"][0]["required_context"] = value.clone() }
            assert_eq!(status(&doc, Surface::CicdSquabbler), 2, "{field}={value}");
        }
    }
}

#[test]
fn unrecognised_run_is_never_green() {
    for run in [json!("bogus"), json!(7), Value::Null] {
        let doc = json!({"required_contexts": ["build"], "checks": [{"required_context": "build", "run": run}]});
        assert_eq!(status(&doc, Surface::CicdSquabbler), 2);
    }
}

#[test]
fn invalid_cli_never_dispatches_a_different_surface() {
    assert!(Surface::parse("typo").is_none());
    let exe = env!("CARGO_BIN_EXE_check-contract");
    for args in [vec![], vec!["proven-tests", "ignored"], vec!["validate-file", "x", "typo"]] {
        let out = std::process::Command::new(exe).args(&args).output().unwrap();
        assert_eq!(out.status.code(), Some(2), "{args:?}");
    }
}

#[test]
fn missing_and_unparseable_files_mean_no_check() {
    let dir = tempdir("files");
    let report = dir.join("report.json");
    let mut sink = Vec::new();
    assert!(validate_file(&report, Surface::ProvenTests, &mut sink).is_err());
    std::fs::write(&report, "{").unwrap();
    assert!(validate_file(&report, Surface::ProvenTests, &mut sink).is_err());

    let surface = dir.join("proven-tests");
    std::fs::create_dir_all(&surface).unwrap();
    assert!(run_surface(&dir, Surface::ProvenTests, &mut sink).is_err());
    std::fs::write(surface.join("cases.json"), "{").unwrap();
    assert!(run_surface(&dir, Surface::ProvenTests, &mut sink).is_err());
}

#[test]
fn the_shipped_cases_hold() {
    let mut sink = Vec::new();
    for s in [Surface::ProvenTests, Surface::CicdSquabbler] {
        assert_eq!(run_surface(&contract_root(), s, &mut sink).unwrap(), 0, "{}", String::from_utf8_lossy(&sink));
    }
}

#[test]
fn null_proof_ladder_and_null_category_are_accepted_and_cover_nothing() {
    let mut doc = clean();
    doc["entries"][0]["proof_ladder"] = Value::Null;
    assert_eq!(status(&doc, Surface::ProvenTests), 0, "null ladder is an empty ladder");
    let (v, cells) = proven_evidence::validate_with_cells(&clean()).unwrap();
    assert!(v.is_empty());
    let mut d = clean();
    d["entries"][0]["category"] = Value::Null;
    let (_, cells2) = proven_evidence::validate_with_cells(&d).unwrap();
    assert!(cells2 <= cells, "an entry with no category covers no cell");
    let mut e = clean();
    e["entries"][0]["category"] = json!("");
    assert_eq!(proven_evidence::validate_with_cells(&e).unwrap().1, cells2);
}

#[test]
fn emitter_rejects_non_string_category() {
    use proven_evidence::emit::{emit, EmitError};
    let doc = json!({"tests": [{"module": "m", "name": "n", "category": 12, "aspect": "a",
        "tier": "Unproven", "outcome": "passed", "fixture_obligation": "CannotFailByDesign"}]});
    assert!(matches!(emit(&doc), Err(EmitError::Dishonest(_))));
}

#[test]
fn unloadable_fixture_means_no_check_performed() {
    let dir = tempdir("nofix");
    let s = dir.join("proven-tests");
    std::fs::create_dir_all(&s).unwrap();
    std::fs::write(s.join("cases.json"), r#"{"cases":[{"id":"x","fixture":"gone.json","expect":{"valid":true}}]}"#).unwrap();
    let mut sink = Vec::new();
    assert_eq!(run_surface(&dir, Surface::ProvenTests, &mut sink).unwrap(), 2);
}
