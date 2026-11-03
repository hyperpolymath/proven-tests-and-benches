// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! Execution-observation contract v1, independent of Idris2 and CI products.
//! Candidate means "passed this consumer's external receipt verifier", not a proof.
use serde::Deserialize;
use std::collections::BTreeSet;

#[derive(Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Stage { Setup, Substantive, Harness }
#[derive(Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Outcome { Passed, Failed, Skipped, Unavailable }
#[derive(Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Freshness { Current, Expired, Retracted }

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Observation {
    pub obligation: String,
    pub subject_id: String,
    pub source_revision: String,
    pub checker_id: String,
    pub checker_version: String,
    pub checker_config_digest: String,
    pub checker_trusted_base: String,
    pub stage: Stage,
    pub outcome: Outcome,
    pub attempt_id: String,
    pub delivery_id: String,
    pub receipt_ref: String,
    pub freshness: Freshness,
    pub retracted: bool,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Envelope {
    pub contract_version: String,
    pub subject_id: String,
    pub source_revision: String,
    pub claim_property: String,
    pub declared_scope: String,
    pub required: Vec<String>,
    pub scheduled: Vec<String>,
    pub jobs_started: usize,
    pub min_independent: usize,
    pub observations: Vec<Observation>,
    pub claimed_green: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub enum Decision {
    Candidate,
    Denied(&'static str),
    NotRun(&'static str),
}

/// Every production consumer supplies independent authentication of the
/// source, run, obligation and checker identity. No default verifier exists.
pub trait ReceiptVerifier {
    fn verifies(&self, observation: &Observation, claim: &Envelope) -> bool;
}

pub fn classify_json(
    input: &str, verifier: &impl ReceiptVerifier
) -> Result<Decision, serde_json::Error> {
    let envelope: Envelope = serde_json::from_str(input)?;
    Ok(classify(&envelope, verifier))
}

pub fn classify(c: &Envelope, verifier: &impl ReceiptVerifier) -> Decision {
    if c.contract_version != "1.0.0" {
        return Decision::Denied("unsupported_contract_version");
    }
    if c.subject_id.is_empty()
        || c.source_revision.len() != 40
        || !c.source_revision.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
        || c.claim_property.is_empty()
        || c.declared_scope.is_empty() {
        return Decision::Denied("missing_or_invalid_subject_claim");
    }
    if c.required.is_empty() { return Decision::Denied("empty_required_set"); }
    let obligations: BTreeSet<&str> = c.required.iter().map(String::as_str).collect();
    if obligations.len() != c.required.len() || obligations.contains("") {
        return Decision::Denied("duplicate_or_empty_obligation");
    }
    if c.jobs_started == 0 { return Decision::Denied("zero_jobs"); }
    if c.min_independent == 0 { return Decision::Denied("zero_confirmation_threshold"); }
    if c.observations.iter().any(|o| o.stage == Stage::Harness && o.outcome == Outcome::Failed) {
        return Decision::Denied("harness_failure_not_subject_failure");
    }
    for obligation in obligations {
        if !c.scheduled.iter().any(|s| s == obligation) {
            return Decision::Denied("not_scheduled");
        }
        let seen: Vec<&Observation> = c.observations.iter()
            .filter(|o| o.obligation == obligation).collect();
        if seen.is_empty() {
            return if c.observations.is_empty() {
                Decision::NotRun("no_observations")
            } else {
                Decision::Denied("wrong_obligation")
            };
        }
        if seen.iter().any(|o| o.checker_id.is_empty()
            || o.checker_version.is_empty()
            || o.checker_config_digest.is_empty()
            || o.checker_trusted_base.is_empty()
            || o.outcome == Outcome::Unavailable) {
            return Decision::NotRun("unknown_checker");
        }
        if seen.iter().any(|o| o.retracted || o.freshness == Freshness::Retracted) {
            return Decision::Denied("retracted_evidence");
        }
        if seen.iter().any(|o| o.subject_id != c.subject_id
            || o.source_revision != c.source_revision
            || o.freshness != Freshness::Current) {
            return Decision::Denied("wrong_or_stale_revision");
        }
        if seen.iter().any(|o| o.outcome == Outcome::Skipped) {
            return Decision::Denied("required_skipped");
        }
        if seen.iter().any(|o| o.outcome == Outcome::Failed && o.stage == Stage::Substantive) {
            return Decision::Denied("failed_substantive_validator");
        }
        if seen.iter().all(|o| o.stage == Stage::Setup) {
            return Decision::Denied("setup_only");
        }
        let valid: Vec<&Observation> = seen.iter()
            .copied()
            .filter(|o| o.stage == Stage::Substantive && o.outcome == Outcome::Passed
                && !o.receipt_ref.is_empty()
                && !o.attempt_id.is_empty()
                && !o.delivery_id.is_empty()
                && verifier.verifies(o, c))
            .collect();
        if valid.is_empty() {
            return Decision::NotRun("no_verified_substantive_receipt");
        }
        let attempts: BTreeSet<&str> = valid.iter().map(|o| o.attempt_id.as_str()).collect();
        let deliveries: BTreeSet<&str> = valid.iter().map(|o| o.delivery_id.as_str()).collect();
        let receipts: BTreeSet<&str> = valid.iter().map(|o| o.receipt_ref.as_str()).collect();
        if attempts.len() < c.min_independent
            || deliveries.len() < c.min_independent
            || receipts.len() < c.min_independent {
            return Decision::Denied("duplicate_delivery_not_independent");
        }
    }
    Decision::Candidate
}
