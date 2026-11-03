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
