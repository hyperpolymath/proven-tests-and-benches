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
    /// Return whether this observation's receipt and checker are accepted for
    /// the claim. Rejected observations do not count towards confirmation.
    fn verifies(&self, observation: &Observation, claim: &Envelope) -> bool;
}

/// Deserialise an execution envelope and classify it using `verifier`.
///
/// # Errors
/// Returns the JSON deserialisation error if the input is invalid or does not
/// match the envelope's expected fields and types.
pub fn classify_json(
    input: &str, verifier: &impl ReceiptVerifier
) -> Result<Decision, serde_json::Error> {
    let envelope: Envelope = serde_json::from_str(input)?;
    Ok(classify(&envelope, verifier))
}

/// Search for an exact, pairwise independent subset. In three dimensions
/// (attempt, delivery, receipt) checking distinct counts is unsound, while a
/// one-pass greedy choice depends on observation order. Exhaustive backtracking
/// is bounded: exceeding the search budget is NotRun, never a false denial or
/// a false Candidate. The limits protect untrusted external evidence inputs.
fn independent_subset(candidates: &[&Observation], need: usize) -> Option<bool> {
    const SEARCH_BUDGET: usize = 200_000;
    // A state budget alone cannot cap stack depth when excluding a long
    // incompatible suffix. Report NotRun on oversized untrusted input rather
    // than risking a stack overflow or pretending to have decided the claim.
    const MAX_RECURSION_DEPTH: usize = 128;
    fn search<'a>(
        left: &[&'a Observation], need: usize, selected: &mut Vec<&'a Observation>,
        budget: &mut usize,
    ) -> Option<bool> {
        if need == 0 { return Some(true); }
        if left.len() < need { return Some(false); }
        if *budget == 0 { return None; }
        *budget -= 1;
        let (first, rest) = left.split_first().expect("checked nonempty above");
        let compatible = selected.iter().all(|prior| {
            first.attempt_id != prior.attempt_id
                && first.delivery_id != prior.delivery_id
                && first.receipt_ref != prior.receipt_ref
        });
        let include = if compatible {
            selected.push(*first);
            let answer = search(rest, need - 1, selected, budget);
            selected.pop();
            answer
        } else { Some(false) };
        if include == Some(true) { return Some(true); }
        let exclude = search(rest, need, selected, budget);
        if exclude == Some(true) { Some(true) }
        else if include.is_none() || exclude.is_none() { None }
        else { Some(false) }
    }
    if need == 0 { return Some(true); }
    if candidates.len() < need { return Some(false); }

    // Canonicalize by the three identity dimensions. Duplicate triples
    // cannot contribute additional independent confirmations.
    let mut ordered: Vec<&Observation> = candidates.to_vec();
    ordered.sort_unstable_by(|a, b| {
        (a.attempt_id.as_str(), a.delivery_id.as_str(), a.receipt_ref.as_str())
            .cmp(&(b.attempt_id.as_str(), b.delivery_id.as_str(), b.receipt_ref.as_str()))
    });
    ordered.dedup_by(|a, b| {
        a.attempt_id == b.attempt_id
            && a.delivery_id == b.delivery_id
            && a.receipt_ref == b.receipt_ref
    });
    if ordered.len() < need { return Some(false); }

    // Marginal distinct-ID counts are necessary, not sufficient. It is
    // sound to reject when any one dimension has too few distinct IDs.
    let attempts: BTreeSet<&str> = ordered.iter().map(|o| o.attempt_id.as_str()).collect();
    let deliveries: BTreeSet<&str> = ordered.iter().map(|o| o.delivery_id.as_str()).collect();
    let receipts: BTreeSet<&str> = ordered.iter().map(|o| o.receipt_ref.as_str()).collect();
    if attempts.len() < need || deliveries.len() < need || receipts.len() < need {
        return Some(false);
    }

    // A greedy *success* is a constructive witness. Its failure does not
    // imply nonexistence, and therefore is never a Denied result.
    // Separate identity sets preserve the greedy choices without scanning
    // every previously chosen observation for each candidate.
    let mut chosen_attempts = BTreeSet::new();
    let mut chosen_deliveries = BTreeSet::new();
    let mut chosen_receipts = BTreeSet::new();
    for candidate in &ordered {
        if !chosen_attempts.contains(candidate.attempt_id.as_str())
            && !chosen_deliveries.contains(candidate.delivery_id.as_str())
            && !chosen_receipts.contains(candidate.receipt_ref.as_str())
        {
            chosen_attempts.insert(candidate.attempt_id.as_str());
            chosen_deliveries.insert(candidate.delivery_id.as_str());
            chosen_receipts.insert(candidate.receipt_ref.as_str());
            if chosen_attempts.len() >= need { return Some(true); }
        }
    }

    // Only unresolved inputs need exact search. Fixed sorting ensures
    // equivalent input permutations consume the same search budget.
    if ordered.len() > MAX_RECURSION_DEPTH { return None; }
    let mut budget = SEARCH_BUDGET;
    search(&ordered, need, &mut Vec::new(), &mut budget)
}

/// Classify an execution claim using verified substantive receipts.
///
/// `Candidate` requires every required obligation to pass the checks; it is
/// not a proof certificate. `Denied` identifies a disqualifying condition,
/// while `NotRun` identifies missing or unusable evidence. The claimed green
/// summary is ignored. Obligations are checked in sorted order and the first
/// non-candidate decision is returned.
///
/// For each obligation, evidence is admitted only if some subset of verified
/// observations has mutually distinct attempt, delivery and receipt IDs.
/// Exhausting the bounded search returns NotRun, not success or denial.
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
        if seen.iter().any(|o| o.stage == Stage::Setup && o.outcome == Outcome::Failed) {
            return Decision::Denied("setup_failure");
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
        match independent_subset(&valid, c.min_independent) {
            Some(true) => {}
            Some(false) => return Decision::Denied("duplicate_delivery_not_independent"),
            None => return Decision::NotRun("independence_search_incomplete"),
        }
    }
    Decision::Candidate
}
