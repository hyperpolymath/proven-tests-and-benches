// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Reusable positive/negative parser fixtures and non-vacuous execution.
//!
//! This harness is ordinary Rust testing, classified Unproven. A successful
//! fixture establishes its observed behavior, not universal parser correctness.
use std::collections::BTreeSet;
use std::time::{Duration, Instant};

/// Expected canonical bytes, or rejection of malformed/unsupported input.
#[derive(Clone, Debug)]
pub enum Expected {
    Canonical(Vec<u8>),
    Reject,
}
/// An independently specified parser fixture.
#[derive(Clone, Debug)]
pub struct Case {
    pub id: String,
    pub input: Vec<u8>,
    pub expected: Expected,
}
/// The observed result of a fixture execution.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Observation {
    pub id: String,
    pub passed: bool,
    pub detail: String,
}
/// Check the corpus before running a parser. Empty, duplicate and one-sided
/// corpora cannot qualify as a conformance suite.
pub fn validate_cases(cases: &[Case]) -> Result<(), String> {
    let mut ids = BTreeSet::new();
    let mut accepted = false;
    let mut rejected = false;
    for case in cases {
        if case.id.trim().is_empty() || !ids.insert(&case.id) {
            return Err(format!(
                "empty or duplicate fixture identifier: {:?}",
                case.id
            ));
        }
        match case.expected {
            Expected::Canonical(_) => accepted = true,
            Expected::Reject => rejected = true,
        }
    }
    if !accepted || !rejected {
        return Err("conformance requires both accepted and rejected fixtures".into());
    }
    Ok(())
}
/// Execute every fixture. The adapter returns canonical bytes or a diagnostic.
/// Parser panics propagate as test failures; they are never mistaken for rejection.
pub fn run(
    cases: &[Case],
    mut parser: impl FnMut(&[u8]) -> Result<Vec<u8>, String>,
) -> Result<Vec<Observation>, String> {
    validate_cases(cases)?;
    Ok(cases
        .iter()
        .map(|case| {
            let actual = parser(&case.input);
            let (passed, detail) = match (&case.expected, actual) {
                (Expected::Canonical(expected), Ok(actual)) if *expected == actual => {
                    (true, "canonical bytes match".into())
                }
                (Expected::Reject, Err(_)) => (true, "invalid input rejected".into()),
                (Expected::Canonical(_), Err(reason)) => {
                    (false, format!("valid input rejected: {reason}"))
                }
                (Expected::Reject, Ok(_)) => (false, "invalid input accepted".into()),
                (Expected::Canonical(_), Ok(_)) => (false, "canonical byte mismatch".into()),
            };
            Observation {
                id: case.id.clone(),
                passed,
                detail,
            }
        })
        .collect())
}
/// Require every actual execution to pass; an empty result cannot pass.
pub fn require_pass(observations: &[Observation]) -> Result<(), String> {
    if observations.is_empty() {
        return Err("no fixture executed".into());
    }
    let failures: Vec<_> = observations
        .iter()
        .filter(|o| !o.passed)
        .map(|o| format!("{}: {}", o.id, o.detail))
        .collect();
    if failures.is_empty() {
        Ok(())
    } else {
        Err(failures.join("\n"))
    }
}
/// A benchmark sample records work performed and elapsed wall time.
#[derive(Clone, Debug)]
pub struct Sample {
    pub iterations: u64,
    pub bytes_per_iteration: usize,
    pub elapsed: Duration,
}
/// Benchmark a fallible parser with black-boxed input/output. A failing parser
/// or zero-iteration request cannot emit a successful timing.
pub fn benchmark<T>(
    input: &[u8],
    iterations: u64,
    mut parser: impl FnMut(&[u8]) -> Result<T, String>,
) -> Result<Sample, String> {
    if iterations == 0 {
        return Err("benchmark requires at least one iteration".into());
    }
    let start = Instant::now();
    for _ in 0..iterations {
        std::hint::black_box(parser(std::hint::black_box(input))?);
    }
    Ok(Sample {
        iterations,
        bytes_per_iteration: input.len(),
        elapsed: start.elapsed(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    fn cases() -> Vec<Case> {
        vec![
            Case {
                id: "valid".into(),
                input: b" input ".to_vec(),
                expected: Expected::Canonical(b"output".to_vec()),
            },
            Case {
                id: "invalid".into(),
                input: b"bad".to_vec(),
                expected: Expected::Reject,
            },
        ]
    }
    #[test]
    fn corrupt_parsers_fail_the_harness() {
        for parser in [
            (|_: &[u8]| Ok(b"output".to_vec())) as fn(&[u8]) -> Result<Vec<u8>, String>,
            |_| Err("always rejects".into()),
            |input| Ok(input.to_vec()),
        ] {
            assert!(require_pass(&run(&cases(), parser).unwrap()).is_err());
        }
        let correct = run(&cases(), |input| {
            if input == b"bad" {
                Err("rejected".into())
            } else {
                Ok(b"output".to_vec())
            }
        })
        .unwrap();
        require_pass(&correct).unwrap();
    }
    #[test]
    fn vacuous_and_duplicate_corpora_are_refused() {
        assert!(validate_cases(&[]).is_err());
        assert!(validate_cases(&cases()[..1]).is_err());
        let mut duplicate = cases();
        duplicate.push(duplicate[0].clone());
        assert!(validate_cases(&duplicate).is_err());
        assert!(require_pass(&[]).is_err());
    }
    #[test]
    fn all_fixtures_execute_even_after_a_mismatch() {
        let mut calls = 0;
        let results = run(&cases(), |_| {
            calls += 1;
            Ok(vec![])
        })
        .unwrap();
        assert_eq!(calls, 2);
        assert_eq!(results.len(), 2);
        assert!(results.iter().all(|r| !r.passed));
    }
    #[test]
    fn benchmark_reports_only_executed_successful_work() {
        assert!(benchmark(b"x", 0, |_| Ok(())).is_err());
        assert!(benchmark::<()>(b"x", 1, |_| Err("parser failed".into())).is_err());
        let mut calls = 0;
        let sample = benchmark(b"abc", 5, |_| {
            calls += 1;
            Ok(())
        })
        .unwrap();
        assert_eq!(calls, 5);
        assert_eq!(sample.iterations, 5);
        assert_eq!(sample.bytes_per_iteration, 3);
    }
}
