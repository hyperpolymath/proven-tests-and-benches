// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Case runner and single-file validator for the two contract surfaces.
//
// EXIT CODES (the repository's standing three-outcome convention):
//   0  every case ran and every expectation held
//   1  at least one case produced the wrong verdict
//   2  NO CHECK WAS PERFORMED — a fixture or case file is missing or unparseable

use crate::gate;
use serde_json::Value;
use std::path::Path;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Surface {
    ProvenTests,
    CicdSquabbler,
}

impl Surface {
    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "proven-tests" => Some(Self::ProvenTests),
            "cicd-squabbler" => Some(Self::CicdSquabbler),
            _ => None,
        }
    }
    pub fn dir(self) -> &'static str {
        match self {
            Self::ProvenTests => "proven-tests",
            Self::CicdSquabbler => "cicd-squabbler",
        }
    }
}

/// Read a UTF-8 JSON file; Err means no check could be performed.
pub fn load(path: &Path) -> Result<Value, String> {
    if !path.is_file() {
        return Err(format!("missing file: {}", path.display()));
    }
    let raw = std::fs::read_to_string(path).map_err(|e| format!("cannot read {}: {e}", path.display()))?;
    serde_json::from_str(&raw).map_err(|e| format!("unparseable JSON in {}: {e}", path.display()))
}

fn actual_for(surface: Surface, doc: &Value) -> Result<(Value, Vec<String>), String> {
    match surface {
        Surface::ProvenTests => {
            let (violations, derived) = crate::validate_with_cells(doc)?;
            Ok((serde_json::json!({"valid": violations.is_empty(), "derived_covered_cells": derived}), violations))
        }
        Surface::CicdSquabbler => {
            let v = gate::validate_squabbler_gate(doc)?;
            Ok((
                serde_json::json!({
                    "gate_state": v.gate_state.as_str(),
                    "legitimate_green": v.legitimate_green,
                    "evidence_free": v.evidence_free,
                }),
                vec![],
            ))
        }
    }
}

/// Run a surface's fixture cases under `root` (the contract directory).
pub fn run_surface(root: &Path, surface: Surface, out: &mut impl std::io::Write) -> Result<i32, String> {
    let dir = root.join(surface.dir());
    let cases_doc = load(&dir.join("cases.json"))?;
    let cases = cases_doc
        .get("cases")
        .and_then(Value::as_array)
        .ok_or("cases.json has no 'cases' array")?;
    let (mut failures, mut ran) = (0usize, 0usize);
    let w = |e: std::io::Error| format!("write failed: {e}");
    for case in cases {
        let id = case.get("id").and_then(Value::as_str).unwrap_or("?");
        let fixture = case.get("fixture").and_then(Value::as_str).ok_or("case has no fixture")?;
        let loaded = load(&dir.join(fixture)).and_then(|d| actual_for(surface, &d));
        let (actual, violations) = match loaded {
            Ok(x) => x,
            Err(e) => {
                writeln!(out, "  FAIL {id}: no check performed — {e}").map_err(w)?;
                failures += 1;
                continue;
            }
        };
        ran += 1;
        let expect = case.get("expect").and_then(Value::as_object).ok_or("case has no expect")?;
        let bad: Vec<String> = expect
            .iter()
            .filter(|(k, want)| actual.get(k.as_str()) != Some(*want))
            .map(|(k, want)| format!("{k}={} (expected {want})", actual.get(k.as_str()).unwrap_or(&Value::Null)))
            .collect();
        if bad.is_empty() {
            let shown: Vec<String> = expect.iter().map(|(k, v)| format!("{k}={v}")).collect();
            writeln!(out, "  ok   {id}: {}", shown.join(", ")).map_err(w)?;
        } else {
            failures += 1;
            writeln!(out, "  FAIL {id}: {}", bad.join("; ")).map_err(w)?;
        }
        if surface == Surface::ProvenTests {
            if let Some(reason) = case.get("expect_invalid_reason").and_then(Value::as_str) {
                if violations.is_empty() {
                    writeln!(out, "  FAIL {id}: expected invalidity but report validated").map_err(w)?;
                    failures += 1;
                } else if !violations.iter().any(|t| t.contains(reason)) {
                    writeln!(out, "  FAIL {id}: invalid for the wrong reason; wanted a violation mentioning {reason:?}").map_err(w)?;
                    failures += 1;
                }
            }
        }
    }
    writeln!(out, "{}: {}/{ran} case(s) passed", surface.dir(), ran.saturating_sub(failures)).map_err(w)?;
    Ok(if failures > 0 { 1 } else { 0 })
}

/// Validate one file against a surface; returns the exit status.
pub fn validate_file(path: &Path, surface: Surface, out: &mut impl std::io::Write) -> Result<i32, String> {
    let doc = load(path)?;
    let w = |e: std::io::Error| format!("write failed: {e}");
    match surface {
        Surface::ProvenTests => match crate::validate_with_cells(&doc) {
            Err(e) => {
                writeln!(out, "NO CHECK PERFORMED: {e}").map_err(w)?;
                Ok(2)
            }
            Ok((violations, derived)) => {
                if violations.is_empty() {
                    writeln!(out, "CONFORMANT").map_err(w)?;
                    writeln!(out, "derived_covered_cells={derived}").map_err(w)?;
                    Ok(0)
                } else {
                    writeln!(out, "NOT CONFORMANT:").map_err(w)?;
                    for v in &violations {
                        writeln!(out, "  - {v}").map_err(w)?;
                    }
                    writeln!(out, "derived_covered_cells={derived}").map_err(w)?;
                    Ok(1)
                }
            }
        },
        Surface::CicdSquabbler => match gate::validate_squabbler_gate(&doc) {
            Err(e) => {
                writeln!(out, "NO CHECK PERFORMED: {e}").map_err(w)?;
                Ok(2)
            }
            Ok(v) => {
                writeln!(out, "gate_state={} legitimate_green={} evidence_free={}",
                    v.gate_state.as_str(), if v.legitimate_green { "True" } else { "False" }, v.evidence_free).map_err(w)?;
                writeln!(out, "CONFORMANT").map_err(w)?;
                Ok(0)
            }
        },
    }
}
