// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
use proven_evidence::execution_truth::{
    classify_json, Decision, Envelope, Observation, ReceiptVerifier
};
struct SyntheticOnly;
impl ReceiptVerifier for SyntheticOnly {
    fn verifies(&self, o: &Observation, c: &Envelope) -> bool {
        // ONLY a committed offline fixture. NEVER production authentication.
        o.receipt_ref == "fixture:receipt-1"
            && o.subject_id == c.subject_id
            && o.source_revision == c.source_revision
    }
}
const CLEAN: &str = include_str!("../../../../../execution-truth/v1/fixtures/clean.json");
const FIRING: &str = include_str!("../../../../../execution-truth/v1/fixtures/firing.json");
const VOID: &str = include_str!("../../../../../execution-truth/v1/fixtures/void.json");

#[test]
fn clean_fixture_is_candidate_not_proof() {
    assert_eq!(classify_json(CLEAN, &SyntheticOnly).unwrap(), Decision::Candidate);
}
#[test]
fn planted_failed_validator_is_rejected_even_if_green_claimed() {
    assert_eq!(classify_json(FIRING, &SyntheticOnly).unwrap(),
               Decision::Denied("failed_substantive_validator"));
}
#[test]
fn not_run_is_never_reported_as_pass() {
    assert_eq!(classify_json(VOID, &SyntheticOnly).unwrap(),
               Decision::NotRun("no_observations"));
}
#[test]
fn missing_verifier_trust_is_not_success() {
    struct RejectAll;
    impl ReceiptVerifier for RejectAll {
        fn verifies(&self, _: &Observation, _: &Envelope) -> bool { false }
    }
    assert_eq!(classify_json(CLEAN, &RejectAll).unwrap(),
               Decision::NotRun("no_verified_substantive_receipt"));
}
#[test]
fn json_proof_claim_cannot_mint_a_typed_certificate() {
    let mut value: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    value["proof_tier"] = serde_json::json!("ActuallyProven");
    assert!(classify_json(&value.to_string(), &SyntheticOnly).is_err());
}

#[test]
fn delivery_replay_cannot_be_relabelled_as_two_attempts() {
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    doc["min_independent"] = serde_json::json!(2);
    let mut second = doc["observations"][0].clone();
    second["attempt_id"] = serde_json::json!("run-2");
    doc["observations"].as_array_mut().unwrap().push(second);
    assert_eq!(classify_json(&doc.to_string(), &SyntheticOnly).unwrap(),
               Decision::Denied("duplicate_delivery_not_independent"));
}

/// Exercise a planted deviation against the *real* execution-truth classifier.
/// The receipt verifier is deliberately fixture-only: these are semantic
/// regression controls, not independently authenticated production CI runs.
fn with_clean_mutant(mutate: impl FnOnce(&mut serde_json::Value)) -> Decision {
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    mutate(&mut doc);
    classify_json(&doc.to_string(), &SyntheticOnly).unwrap()
}

#[test]
fn empty_obligations_or_unscheduled_mandatory_work_cannot_pass() {
    assert_eq!(
        with_clean_mutant(|d| d["required"] = serde_json::json!([])),
        Decision::Denied("empty_required_set")
    );
    assert_eq!(
        with_clean_mutant(|d| d["scheduled"] = serde_json::json!([])),
        Decision::Denied("not_scheduled")
    );
}

#[test]
fn zero_started_jobs_or_zero_independent_confirmations_cannot_pass() {
    assert_eq!(
        with_clean_mutant(|d| d["jobs_started"] = serde_json::json!(0)),
        Decision::Denied("zero_jobs")
    );
    assert_eq!(
        with_clean_mutant(|d| d["min_independent"] = serde_json::json!(0)),
        Decision::Denied("zero_confirmation_threshold")
    );
}

#[test]
fn setup_success_is_not_a_substantive_check() {
    assert_eq!(
        with_clean_mutant(|d| d["observations"][0]["stage"] = serde_json::json!("setup")),
        Decision::Denied("setup_only")
    );
}

#[test]
fn setup_failure_is_not_misreported_as_subject_failure() {
    assert_eq!(
        with_clean_mutant(|d| {
            d["observations"][0]["stage"] = serde_json::json!("setup");
            d["observations"][0]["outcome"] = serde_json::json!("failed");
        }),
        Decision::Denied("setup_failure")
    );
}

#[test]
fn harness_failure_is_not_misreported_as_subject_failure() {
    assert_eq!(
        with_clean_mutant(|d| {
            d["observations"][0]["stage"] = serde_json::json!("harness");
            d["observations"][0]["outcome"] = serde_json::json!("failed");
        }),
        Decision::Denied("harness_failure_not_subject_failure")
    );
}

#[test]
fn required_skipped_check_is_never_success_even_when_green_claimed() {
    assert_eq!(
        with_clean_mutant(|d| d["observations"][0]["outcome"] = serde_json::json!("skipped")),
        Decision::Denied("required_skipped")
    );
}

#[test]
fn missing_checker_and_unavailable_check_are_not_run() {
    assert_eq!(
        with_clean_mutant(|d| d["observations"][0]["checker_id"] = serde_json::json!("")),
        Decision::NotRun("unknown_checker")
    );
    assert_eq!(
        with_clean_mutant(|d| {
            d["observations"][0]["outcome"] = serde_json::json!("unavailable")
        }),
        Decision::NotRun("unknown_checker")
    );
}

#[test]
fn stale_revision_and_retracted_receipt_cannot_warrant_success() {
    assert_eq!(
        with_clean_mutant(|d| {
            d["observations"][0]["source_revision"] =
                serde_json::json!("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
        }),
        Decision::Denied("wrong_or_stale_revision")
    );
    assert_eq!(
        with_clean_mutant(|d| d["observations"][0]["retracted"] = serde_json::json!(true)),
        Decision::Denied("retracted_evidence")
    );
}

#[test]
fn absent_substantive_receipt_is_not_run_not_pass() {
    assert_eq!(
        with_clean_mutant(|d| d["observations"][0]["receipt_ref"] = serde_json::json!("")),
        Decision::NotRun("no_verified_substantive_receipt")
    );
}

#[test]
fn unsupported_contract_version_is_explicitly_rejected() {
    assert_eq!(
        with_clean_mutant(|d| d["contract_version"] = serde_json::json!("2.0.0")),
        Decision::Denied("unsupported_contract_version")
    );
}

#[test]
fn positive_candidate_does_not_depend_on_producers_green_claim() {
    // The adjudicator ignores an asserted claim, in BOTH directions. This
    // only qualifies the synthetic offline fixture, not a real CI receipt.
    assert_eq!(
        with_clean_mutant(|d| d["claimed_green"] = serde_json::json!(false)),
        Decision::Candidate
    );
}
