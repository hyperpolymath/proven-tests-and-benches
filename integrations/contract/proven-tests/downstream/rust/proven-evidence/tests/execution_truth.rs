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

#[test]
fn overlapping_identity_columns_are_not_independent_confirmations() {
    struct OfflineFixture;
    impl ReceiptVerifier for OfflineFixture {
        fn verifies(&self, o: &Observation, c: &Envelope) -> bool {
            o.receipt_ref.starts_with("fixture:receipt-")
                && o.subject_id == c.subject_id
                && o.source_revision == c.source_revision
        }
    }
    // Silence and void are committed fixtures, not hand-waved results.
    assert_eq!(classify_json(CLEAN, &OfflineFixture).unwrap(), Decision::Candidate);
    assert_eq!(classify_json(VOID, &OfflineFixture).unwrap(),
               Decision::NotRun("no_observations"));
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    doc["min_independent"] = serde_json::json!(2);
    let a = doc["observations"][0].clone();
    let mut b = a.clone();
    b["delivery_id"] = serde_json::json!("delivery-B");
    b["receipt_ref"] = serde_json::json!("fixture:receipt-2");
    let mut c = a.clone();
    c["attempt_id"] = serde_json::json!("attempt-B");
    c["receipt_ref"] = serde_json::json!("fixture:receipt-2");
    doc["observations"] = serde_json::json!([a,b,c]);
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(),
               Decision::Denied("duplicate_delivery_not_independent"));
}

#[test]
fn genuinely_independent_pair_is_order_invariant() {
    struct OfflineFixture;
    impl ReceiptVerifier for OfflineFixture {
        fn verifies(&self, o: &Observation, c: &Envelope) -> bool {
            o.receipt_ref.starts_with("fixture:receipt-")
                && o.subject_id == c.subject_id
                && o.source_revision == c.source_revision
        }
    }
    assert_eq!(classify_json(CLEAN, &OfflineFixture).unwrap(), Decision::Candidate);
    assert_eq!(classify_json(VOID, &OfflineFixture).unwrap(),
               Decision::NotRun("no_observations"));
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    doc["min_independent"] = serde_json::json!(2);
    let a = doc["observations"][0].clone();
    let mut b = a.clone();
    b["delivery_id"] = serde_json::json!("delivery-B");
    b["receipt_ref"] = serde_json::json!("fixture:receipt-2");
    let mut c = a.clone();
    c["attempt_id"] = serde_json::json!("attempt-B");
    c["delivery_id"] = serde_json::json!("delivery-C");
    doc["observations"] = serde_json::json!([a,b,c]);
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(), Decision::Candidate);
    doc["observations"] = serde_json::json!([c,b,a]);
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(), Decision::Candidate);
}

#[test]
fn oversized_duplicate_population_is_conclusively_denied() {
    assert_eq!(classify_json(CLEAN, &SyntheticOnly).unwrap(), Decision::Candidate);
    assert_eq!(classify_json(VOID, &SyntheticOnly).unwrap(),
               Decision::NotRun("no_observations"));
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    let entry = doc["observations"][0].clone();
    doc["observations"] = serde_json::Value::Array(vec![entry; 129]);
    doc["min_independent"] = serde_json::json!(2);
    // Identical receipt/delivery/attempt triples cannot witness a second
    // independent execution even when repeated more than 128 times.
    assert_eq!(classify_json(&doc.to_string(), &SyntheticOnly).unwrap(),
               Decision::Denied("duplicate_delivery_not_independent"));
}

#[test]
fn oversized_obvious_independent_witness_is_accepted_in_either_order() {
    struct OfflineFixture;
    impl ReceiptVerifier for OfflineFixture {
        fn verifies(&self, o: &Observation, c: &Envelope) -> bool {
            o.receipt_ref.starts_with("fixture:receipt-")
                && o.subject_id == c.subject_id && o.source_revision == c.source_revision
        }
    }
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    let first = doc["observations"][0].clone();
    let mut second = first.clone();
    second["attempt_id"] = serde_json::json!("attempt-B");
    second["delivery_id"] = serde_json::json!("delivery-B");
    second["receipt_ref"] = serde_json::json!("fixture:receipt-2");
    let mut population = vec![first; 129];
    population.push(second);
    doc["observations"] = serde_json::json!(population);
    doc["min_independent"] = serde_json::json!(2);
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(), Decision::Candidate);
    doc["observations"].as_array_mut().unwrap().reverse();
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(), Decision::Candidate);
}

#[test]
fn large_independent_population_is_accepted_in_either_order() {
    struct OfflineFixture;
    impl ReceiptVerifier for OfflineFixture {
        fn verifies(&self, o: &Observation, c: &Envelope) -> bool {
            o.receipt_ref.starts_with("fixture:receipt-")
                && o.subject_id == c.subject_id && o.source_revision == c.source_revision
        }
    }
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    let base = doc["observations"][0].clone();
    let population: Vec<_> = (0..4096).map(|n| {
        let mut entry = base.clone();
        entry["attempt_id"] = serde_json::json!(format!("attempt-{n:04}"));
        entry["delivery_id"] = serde_json::json!(format!("delivery-{n:04}"));
        entry["receipt_ref"] = serde_json::json!(format!("fixture:receipt-{n:04}"));
        entry
    }).collect();
    doc["observations"] = serde_json::json!(population);
    doc["min_independent"] = serde_json::json!(4096);
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(), Decision::Candidate);
    doc["observations"].as_array_mut().unwrap().reverse();
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(), Decision::Candidate);
    // A replay cannot supply the final independent confirmation.
    doc["observations"][0] = doc["observations"][1].clone();
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(),
               Decision::Denied("duplicate_delivery_not_independent"));
}

#[test]
fn oversized_intersecting_population_is_order_invariant_not_run() {
    struct OfflineFixture;
    impl ReceiptVerifier for OfflineFixture {
        fn verifies(&self, o: &Observation, c: &Envelope) -> bool {
            o.receipt_ref.starts_with("fixture:receipt-")
                && o.subject_id == c.subject_id && o.source_revision == c.source_revision
        }
    }
    let mut doc: serde_json::Value = serde_json::from_str(CLEAN).unwrap();
    let base = doc["observations"][0].clone();
    // Three families of 43 unique triples each, all pairwise intersecting.
    // A and B share attempt; A and C share delivery; B and C share receipt.
    // Each identity column has multiple distinct values; marginal counts
    // cannot prove the absence of a jointly independent pair.
    let mut population = Vec::new();
    for n in 0..43 {
        let mut a = base.clone();
        a["receipt_ref"] = serde_json::json!(format!("fixture:receipt-a-{n}"));
        population.push(a);
        let mut b = base.clone();
        b["delivery_id"] = serde_json::json!(format!("delivery-b-{n}"));
        population.push(b);
        let mut c = base.clone();
        c["attempt_id"] = serde_json::json!(format!("attempt-c-{n}"));
        population.push(c);
    }
    doc["observations"] = serde_json::json!(population);
    doc["min_independent"] = serde_json::json!(2);
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(),
               Decision::NotRun("independence_search_incomplete"));
    doc["observations"].as_array_mut().unwrap().reverse();
    assert_eq!(classify_json(&doc.to_string(), &OfflineFixture).unwrap(),
               Decision::NotRun("independence_search_incomplete"));
}
