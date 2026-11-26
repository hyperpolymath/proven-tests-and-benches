// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// cicd-squabbler gate contract: a (required-context set, realised-runs) pair
// validated against the "squabble != bypass" invariant. No missing,
// skipped-only, cancelled or failed required check may yield a LEGITIMATE green.
//
// The decision core (`gate_state`, `legitimate_green`, `evidence_free`) is pure
// over `Kind` so it carries Pearlite contracts. Those contracts are compiled
// only under `--cfg creusot`; under a normal `cargo build` they are inert.
// STATUS: contracts are written but NOT machine-checked in this repository's
// CI — they are TESTED (tests/gate.rs, tests/parity.rs), not PROVEN.

use serde_json::Value;

#[cfg(creusot)]
use creusot_contracts::prelude::*;

/// Gate kind of one realised run (mirrors squabble_core::gate::CheckRun).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Passed,
    Skipped,
    Failed,
    Pending,
    Missing,
}

/// Overall gate verdict.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Gate {
    Blocked,
    Red,
    Green,
}

impl Gate {
    pub fn as_str(self) -> &'static str {
        match self {
            Gate::Blocked => "Blocked",
            Gate::Red => "Red",
            Gate::Green => "Green",
        }
    }
}

/// Map a run label to its kind. An unrecognised label is `None`, never Passed.
pub fn kind_of(label: &str) -> Option<Kind> {
    Some(match label {
        "passed" => Kind::Passed,
        "skipped" | "neutral" => Kind::Skipped,
        "failed" | "error" | "timed_out" | "cancelled" | "startup_failure" => Kind::Failed,
        "pending" => Kind::Pending,
        "missing" => Kind::Missing,
        _ => return None,
    })
}

/// Green iff non-empty and every run is Passed or Skipped; Red iff not Green and
/// any run Failed; otherwise Blocked (an empty set is unprotected, not won).
#[cfg_attr(creusot, ensures(kinds@.len() == 0 ==> result == Gate::Blocked))]
pub fn gate_state(kinds: &[Kind]) -> Gate {
    if kinds.is_empty() {
        return Gate::Blocked;
    }
    let mut all_satisfied = true;
    let mut any_failed = false;
    for k in kinds {
        match k {
            Kind::Passed | Kind::Skipped => {}
            Kind::Failed => {
                all_satisfied = false;
                any_failed = true;
            }
            Kind::Pending | Kind::Missing => all_satisfied = false,
        }
    }
    if all_satisfied {
        Gate::Green
    } else if any_failed {
        Gate::Red
    } else {
        Gate::Blocked
    }
}

/// Legitimate green: Green, with at least one Passed run, no Pending/Missing/
/// Failed run, and every required context present among the checks.
/// `required_present` is true iff every required context appears in the checks.
#[cfg_attr(creusot, ensures(result ==> gate_state(kinds) == Gate::Green))]
pub fn legitimate_green(required_nonempty: bool, required_present: bool, kinds: &[Kind]) -> bool {
    if gate_state(kinds) != Gate::Green {
        return false;
    }
    if !required_nonempty || kinds.is_empty() || !required_present {
        return false;
    }
    let mut any_passed = false;
    for k in kinds {
        match k {
            Kind::Passed => any_passed = true,
            Kind::Skipped => {}
            _ => return false,
        }
    }
    any_passed
}

/// Count of Skipped (skipped or neutral) runs: green without evidence.
pub fn evidence_free(kinds: &[Kind]) -> i64 {
    kinds.iter().filter(|k| **k == Kind::Skipped).count() as i64
}

/// Verdict for one gate document.
#[derive(Debug, PartialEq, Eq)]
pub struct Verdict {
    pub gate_state: Gate,
    pub legitimate_green: bool,
    pub evidence_free: i64,
}

/// Validate a gate document. `Err` means no check could be performed
/// (the Python `ContractError`); a Red or Blocked gate is a normal `Ok`.
pub fn validate_squabbler_gate(doc: &Value) -> Result<Verdict, String> {
    let obj = doc.as_object().ok_or("gate is not a JSON object")?;
    let required = obj
        .get("required_contexts")
        .and_then(Value::as_array)
        .ok_or("gate has no 'required_contexts' array")?;
    let checks = obj
        .get("checks")
        .and_then(Value::as_array)
        .ok_or("gate has no 'checks' array")?;

    let mut req: Vec<&str> = Vec::new();
    for c in required {
        match c.as_str() {
            Some(s) if !s.trim().is_empty() => req.push(s),
            _ => return Err("required contexts must be non-empty strings".into()),
        }
    }
    let mut kinds: Vec<Kind> = Vec::new();
    let mut present: Vec<&str> = Vec::new();
    for c in checks {
        let ctx = c
            .as_object()
            .and_then(|o| o.get("required_context"))
            .and_then(Value::as_str)
            .filter(|s| !s.trim().is_empty())
            .ok_or("a check is missing required_context")?;
        present.push(ctx);
        let run = c.get("run");
        let kind = run
            .and_then(Value::as_str)
            .and_then(kind_of)
            .ok_or_else(|| format!("unrecognised check run {}", py_repr(run)))?;
        kinds.push(kind);
    }
    let all_present = req.iter().all(|r| present.contains(r));
    Ok(Verdict {
        gate_state: gate_state(&kinds),
        legitimate_green: legitimate_green(!req.is_empty(), all_present, &kinds),
        evidence_free: evidence_free(&kinds),
    })
}

fn py_repr(v: Option<&Value>) -> String {
    match v {
        None | Some(Value::Null) => "None".into(),
        Some(Value::String(s)) => format!("'{s}'"),
        Some(other) => other.to_string(),
    }
}
