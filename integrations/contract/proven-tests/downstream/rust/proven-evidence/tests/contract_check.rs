// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Malformed evidence must be rejected, never crash or acquire a green verdict.
// These are the former test_check_contract.py and test_adversarial_contract.py,
// run against src/contract_check.rs.

use proven_evidence::contract_check::{check_main, default_root, emit, validate_proven_report};
use serde_json::{json, Value};
use std::path::{Path, PathBuf};

fn clean() -> Value {
    let path = default_root().join("proven-tests/fixtures/report-valid-mixed.json");
    serde_json::from_str(&std::fs::read_to_string(path).expect("fixture")).expect("fixture json")
}

/// A test-owned scratch directory, removed when the guard drops (also on a
/// failed assertion).
struct Scratch(PathBuf);

impl std::ops::Deref for Scratch {
    type Target = Path;
    fn deref(&self) -> &Path {
        &self.0
    }
}

impl Drop for Scratch {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn scratch(name: &str) -> Scratch {
    static NEXT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
    let n = NEXT.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    let dir = std::env::temp_dir().join(format!("proven-contract-{}-{name}-{n}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("scratch dir");
    Scratch(dir)
}

fn run(args: &[&str], root: &Path) -> (i32, String) {
    let args: Vec<String> = args.iter().map(|s| s.to_string()).collect();
    let mut out = Vec::new();
    let code = check_main(&args, root, &mut out);
    (code, String::from_utf8_lossy(&out).into_owned())
}

/// Status of `validate-file` over a document written to disk.
fn status(doc: &Value, surface: &str) -> i32 {
    static NEXT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
    let n = NEXT.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
    let dir = scratch("status");
    let path = dir.join(format!("report-{n}.json"));
    std::fs::write(&path, doc.to_string()).expect("write");
    run(&["validate-file", path.to_str().expect("utf8"), surface], &default_root()).0
}

// ── former test_check_contract.py ───────────────────────────────────────────

#[test]
fn fixture_cases_pass_on_both_surfaces() {
    for surface in ["proven-tests", "cicd-squabbler"] {
        let (code, out) = run(&[surface], &default_root());
        assert_eq!(code, 0, "{surface}:\n{out}");
        assert!(out.contains("case(s) passed"), "{out}");
    }
}

#[test]
fn missing_and_unparseable_files_are_exit_2() {
    let dir = scratch("files");
    let path = dir.join("report.json");
    let _ = std::fs::remove_file(&path);
    let (code, out) = run(&["validate-file", path.to_str().unwrap(), "proven-tests"], &default_root());
    assert_eq!(code, 2);
    assert!(out.contains("NO CHECK PERFORMED"), "{out}");
    std::fs::write(&path, "{").unwrap();
    let (code, out) = run(&["validate-file", path.to_str().unwrap(), "proven-tests"], &default_root());
    assert_eq!(code, 2);
    assert!(out.contains("NO CHECK PERFORMED"), "{out}");

    // The case list itself missing, then unparseable.
    let root = scratch("root");
    std::fs::create_dir_all(root.join("proven-tests")).unwrap();
    let _ = std::fs::remove_file(root.join("proven-tests/cases.json"));
    let (code, out) = run(&["proven-tests"], &root);
    assert_eq!(code, 2);
    assert!(out.contains("NO CHECK PERFORMED"), "{out}");
    std::fs::write(root.join("proven-tests/cases.json"), "{").unwrap();
    let (code, out) = run(&["proven-tests"], &root);
    assert_eq!(code, 2);
    assert!(out.contains("NO CHECK PERFORMED"), "{out}");
}

#[test]
fn a_case_whose_fixture_is_missing_fails_the_run() {
    let root = scratch("nofixture");
    std::fs::create_dir_all(root.join("proven-tests")).unwrap();
    std::fs::write(
        root.join("proven-tests/cases.json"),
        r#"{"cases":[{"id":"gone","fixture":"fixtures/none.json","expect":{"valid":true}}]}"#,
    )
    .unwrap();
    let (code, out) = run(&["proven-tests"], &root);
    assert_eq!(code, 1, "{out}");
    assert!(out.contains("FAIL gone: no check performed"), "{out}");
}

#[test]
fn verdict_statuses_are_preserved() {
    assert_eq!(status(&clean(), "proven-tests"), 0);
    let mut bad = clean();
    bad["summary"]["passed"] = json!(999);
    assert_eq!(status(&bad, "proven-tests"), 1);
    assert_eq!(status(&json!([]), "proven-tests"), 2);
}

// ── former test_adversarial_contract.py ─────────────────────────────────────

#[test]
fn positive_and_boolean_counter_controls() {
    assert_eq!(status(&clean(), "proven-tests"), 0);
    let doc = clean();
    for (key, value) in doc["summary"].as_object().unwrap() {
        if let Some(n) = value.as_i64() {
            let mut mutant = clean();
            mutant["summary"][key] = json!(n != 0);
            assert_ne!(status(&mutant, "proven-tests"), 0, "counter {key} as a bool was accepted");
        }
    }
}

#[test]
fn proof_rung_requires_nonempty_strings() {
    let mut doc = clean();
    doc["entries"][0]["provenance"] = json!("ActuallyProven");
    doc["entries"][0]["proof_ladder"] =
        json!([{"theorem": "Fixture.identity", "statement": "For every x, identity x = x"}]);
    let proven = doc["summary"]["actually_proven"].as_i64().unwrap();
    let prov = doc["summary"]["provisionally_proven"].as_i64().unwrap();
    doc["summary"]["actually_proven"] = json!(proven + 1);
    doc["summary"]["provisionally_proven"] = json!(prov - 1);
    assert_eq!(status(&doc, "proven-tests"), 0);
    for field in ["theorem", "statement"] {
        for value in [json!(true), json!(7), Value::Null, json!(["claim"]), json!({"claim": 1}), json!(""), json!("  ")] {
            let mut mutant = doc.clone();
            mutant["entries"][0]["proof_ladder"][0][field] = value.clone();
            assert_ne!(status(&mutant, "proven-tests"), 0, "{field}={value} was accepted");
        }
    }
}

/// Every path into a JSON document, as a list of keys/indexes.
fn paths(value: &Value, here: &mut Vec<Value>, all: &mut Vec<Vec<Value>>) {
    all.push(here.clone());
    match value {
        Value::Object(m) => {
            for (k, v) in m {
                here.push(json!(k));
                paths(v, here, all);
                here.pop();
            }
        }
        Value::Array(a) => {
            for (i, v) in a.iter().enumerate() {
                here.push(json!(i));
                paths(v, here, all);
                here.pop();
            }
        }
        _ => {}
    }
}

/// A small deterministic generator: the test needs repeatability, not quality.
struct Lcg(u64);
impl Lcg {
    fn next(&mut self, n: usize) -> usize {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        ((self.0 >> 33) as usize) % n
    }
}

#[test]
fn bounded_json_shape_robustness() {
    // Robustness only: a mutation to optional metadata can remain valid.
    // Rejection correctness is tested separately by the labelled controls.
    let base = clean();
    let mut all = Vec::new();
    paths(&base, &mut Vec::new(), &mut all);
    let values = [
        Value::Null, json!(true), json!(false), json!(0), json!(-1), json!(1.5), json!(""), json!("  "),
        json!([]), json!({}), json!(["x"]), json!({"x": true}),
    ];
    let mut rng = Lcg(1371);
    for case in 0..2000 {
        let path = all[rng.next(all.len())].clone();
        let value = values[rng.next(values.len())].clone();
        let mut doc = base.clone();
        if path.is_empty() {
            doc = value;
        } else {
            let mut node = &mut doc;
            for key in &path[..path.len() - 1] {
                node = match key {
                    Value::String(k) => node.get_mut(k.as_str()).unwrap(),
                    other => node.get_mut(other.as_u64().unwrap() as usize).unwrap(),
                };
            }
            match path.last().unwrap() {
                Value::String(k) => node[k.as_str()] = value,
                other => node[other.as_u64().unwrap() as usize] = value,
            }
        }
        // A violation list or an explicit malformed-input error: never a panic.
        match validate_proven_report(&doc) {
            Ok((violations, covered)) => {
                assert!(covered >= 0, "case {case}");
                let _ = violations;
            }
            Err(_) => {}
        }
    }
}

#[test]
fn malformed_nested_types() {
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
fn malformed_contexts() {
    for value in [json!(true), json!(12), json!(["nested"]), json!({"nested": 1}), json!(""), Value::Null] {
        for field in ["required", "check"] {
            let mut doc = json!({"required_contexts": ["build"], "checks": [{"required_context": "build", "run": "passed"}]});
            if field == "required" {
                doc["required_contexts"] = json!([value.clone()]);
            } else {
                doc["checks"][0]["required_context"] = value.clone();
            }
            assert_eq!(status(&doc, "cicd-squabbler"), 2, "{field}={value}");
        }
    }
}

#[test]
fn invalid_cli_never_dispatches_a_different_surface() {
    assert_eq!(status(&json!({"required_contexts": [], "checks": []}), "typo"), 2);
    assert_eq!(run(&[], &default_root()).0, 2);
    assert_eq!(run(&["proven-tests", "ignored"], &default_root()).0, 2);
}

// ── emit-report (the producer half) ─────────────────────────────────────────

#[test]
fn emitted_report_validates_and_derives_coverage() {
    let input = json!({"tests": [{
        "tier": "Unproven", "outcome": "passed", "module": "m", "name": "n",
        "category": "c", "aspect": "a", "silence": "s", "firing": "f"
    }]});
    let report = emit(&input).expect("emit");
    assert_eq!(status(&report, "proven-tests"), 0);
    assert_eq!(report["summary"]["covered_cells"], json!(1));
}

#[test]
fn emit_refuses_dishonest_facts() {
    let base = json!({"tier": "Unproven", "outcome": "passed", "silence": "s", "firing": "f"});
    let mut claims_proof = base.clone();
    claims_proof["tier"] = json!("ActuallyProven");
    let mut no_certs = base.clone();
    no_certs["tier"] = json!("ProvisionallyProven");
    let mut no_pair = base.clone();
    no_pair["silence"] = json!("");
    for t in [claims_proof, no_certs, no_pair] {
        let err = emit(&json!({"tests": [t]})).expect_err("must refuse");
        assert_eq!(err.code, 1, "{}", err.message);
    }
    assert_eq!(emit(&json!([])).expect_err("not an object").code, 2);
    assert_eq!(emit(&json!({})).expect_err("no tests").code, 2);
}

// ── review follow-ups: parsing and comparison fidelity with Python ──────────

fn status_raw(raw: &str, surface: &str) -> i32 {
    let dir = scratch("raw");
    let path = dir.join("doc.json");
    std::fs::write(&path, raw).expect("write");
    run(&["validate-file", path.to_str().expect("utf8"), surface], &default_root()).0
}

fn clean_text() -> String {
    std::fs::read_to_string(default_root().join("proven-tests/fixtures/report-valid-mixed.json")).expect("fixture")
}

#[test]
fn negative_zero_integer_is_a_valid_counter_but_negative_zero_float_is_not() {
    let raw = clean_text();
    assert!(raw.contains("\"failed\": 0"), "fixture shape changed");
    assert_eq!(status_raw(&raw.replace("\"failed\": 0", "\"failed\": -0"), "proven-tests"), 0);
    assert_eq!(status_raw(&raw.replace("\"failed\": 0", "\"failed\": -0.0"), "proven-tests"), 1);
}

#[test]
fn near_two_schema_version_is_not_two() {
    let raw = clean_text();
    let needle = "\"schema_version\": 2";
    assert!(raw.contains(needle), "fixture shape changed");
    assert_eq!(status_raw(&raw.replace(needle, "\"schema_version\": 1.9999999999999998"), "proven-tests"), 1);
}

fn emit_raw(raw: &str) -> Value {
    let dir = scratch("emit");
    let (input, output) = (dir.join("in.json"), dir.join("out.json"));
    std::fs::write(&input, raw).expect("write");
    let args: Vec<String> = vec![input.to_str().unwrap().into(), output.to_str().unwrap().into()];
    let (mut out, mut err) = (Vec::new(), Vec::new());
    let code = proven_evidence::contract_check::emit_main(&args, &mut out, &mut err);
    assert_eq!(code, 0, "{}", String::from_utf8_lossy(&err));
    serde_json::from_str(&std::fs::read_to_string(&output).expect("report")).expect("json")
}

fn one_test(duration: &str) -> String {
    format!(
        "{{\"tests\":[{{\"tier\":\"Unproven\",\"outcome\":\"passed\",\"module\":\"m\",\"name\":\"n\",\"duration_ms\":{duration},\"category\":\"c\",\"aspect\":\"a\",\"silence\":\"s\",\"firing\":\"f\"}}]}}"
    )
}

fn duration_of(report: &Value) -> Value {
    report["entries"][0]["duration_ms"].clone()
}

#[test]
fn emit_keeps_raw_float_and_unicode_digit_and_i64_edge_durations() {
    // raw text, so the test input is not rounded before the code under test sees it
    assert_eq!(duration_of(&emit_raw(&one_test("1.9999999999999998"))), json!(1));
    assert_eq!(duration_of(&emit_raw(&one_test("\"\\u0661\\u0662\""))), json!(12)); // Arabic-Indic 12
    assert_eq!(duration_of(&emit_raw(&one_test("9.21e18"))), json!(9210000000000000000i64));
    assert_eq!(duration_of(&emit_raw(&one_test("-9223372036854775808.0"))), json!(i64::MIN));
}

#[test]
fn emit_rejects_out_of_range_and_non_decimal_digits() {
    let dir = scratch("reject");
    for (i, d) in ["9223372036854775808.0", "\"\\u00b2\"", "\"\\u00bd\""].iter().enumerate() {
        let (input, output) = (dir.join(format!("in{i}.json")), dir.join(format!("out{i}.json")));
        std::fs::write(&input, one_test(d)).unwrap();
        let args: Vec<String> = vec![input.to_str().unwrap().into(), output.to_str().unwrap().into()];
        let (mut out, mut err) = (Vec::new(), Vec::new());
        assert_eq!(proven_evidence::contract_check::emit_main(&args, &mut out, &mut err), 1, "{d}");
    }
}

#[test]
fn numeric_expectations_compare_by_value() {
    let root = scratch("numeq");
    let surface = root.join("cicd-squabbler");
    std::fs::create_dir_all(&surface).unwrap();
    std::fs::write(
        surface.join("gate.json"),
        r#"{"required_contexts":["a"],"checks":[{"required_context":"a","run":"skipped"}]}"#,
    )
    .unwrap();
    let write_cases = |want: &str| {
        std::fs::write(
            surface.join("cases.json"),
            format!(r#"{{"cases":[{{"id":"c","fixture":"gate.json","expect":{{"evidence_free":{want}}}}}]}}"#),
        )
        .unwrap();
    };
    write_cases("1.0");
    assert_eq!(run(&["cicd-squabbler"], &root).0, 0);
    write_cases("1.5");
    assert_eq!(run(&["cicd-squabbler"], &root).0, 1);
}
