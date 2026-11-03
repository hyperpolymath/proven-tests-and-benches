-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
--
-- Execution evidence is not a proof certificate. This is a fail-closed,
-- implementation-neutral model of a *reported* CI observation. The trust
-- of a receipt and checker is supplied by an external verifier.
module ProvenTests.ExecutionTruth

import Data.List

%default total

public export
data Stage = Setup | Substantive | Harness

public export
data Outcome = Succeeded | FailedCheck | WasSkipped | WasUnavailable

public export
record Observation where
  constructor MkObservation
  obligation : String
  subject : String
  revision : String
  checker : String
  stage : Stage
  outcome : Outcome
  receipt : String
  attempt : String
  delivery : String
  retracted : Bool

public export
record ExecutionClaim where
  constructor MkExecutionClaim
  subject : String
  revision : String
  required : List String
  scheduled : List String
  jobCount : Nat
  minIndependent : Nat
  observations : List Observation
  summaryGreen : Bool

-- The denied classes are deliberately distinct: setup and harness defects
-- must never masquerade as failures of the subject under test.
public export
data Denial
  = NotScheduled
  | ZeroJobs
  | SetupOnly
  | SetupFailure
  | RequiredSkipped
  | StaleSubject
  | FailedValidatorWrappedGreen
  | UnknownChecker
  | WrongObligation
  | DuplicateDelivery
  | RetractedEvidence
  | EmptyRequiredSet
  | HarnessFailure
  | ZeroConfirmationThreshold
  | ValidatorFailure

export
Show Denial where
  show NotScheduled = "not-scheduled"
  show ZeroJobs = "zero-jobs"
  show SetupOnly = "setup-only"
  show SetupFailure = "setup-failure"
  show RequiredSkipped = "required-skipped"
  show StaleSubject = "stale-subject"
  show FailedValidatorWrappedGreen = "failed-validator-wrapped-green"
  show UnknownChecker = "unknown-checker"
  show WrongObligation = "wrong-obligation"
  show DuplicateDelivery = "duplicate-delivery"
  show RetractedEvidence = "retracted-evidence"
  show EmptyRequiredSet = "empty-required-set"
  show HarnessFailure = "harness-failure"
  show ZeroConfirmationThreshold = "zero-confirmation-threshold"
  show ValidatorFailure = "validator-failure"

export
Eq Denial where
  x == y = show x == show y

public export
data Decision = Candidate | Denied Denial | Void String

export
Show Decision where
  show Candidate = "CANDIDATE"
  show (Denied d) = "DENIED: " ++ show d
  show (Void reason) = "VOID: " ++ reason

isHarnessFailure : Observation -> Bool
isHarnessFailure o = case (o.stage, o.outcome) of
  (Harness, FailedCheck) => True
  _ => False

isUnavailable : Observation -> Bool
isUnavailable o = case o.outcome of
  WasUnavailable => True
  _ => False

isUnknownChecker : Observation -> Bool
isUnknownChecker o = o.checker == ""

isSkipped : Observation -> Bool
isSkipped o = case o.outcome of
  WasSkipped => True
  _ => False

isFailed : Observation -> Bool
isFailed o = case (o.stage, o.outcome) of
  (Substantive, FailedCheck) => True
  _ => False

isSetupFailure : Observation -> Bool
isSetupFailure o = case (o.stage, o.outcome) of
  (Setup, FailedCheck) => True
  _ => False

isSetup : Observation -> Bool
isSetup o = case o.stage of
  Setup => True
  _ => False

-- Qualification is calculated from the observation, not from summaryGreen.
-- A nonempty receipt ID is a *reference*, not cryptographic validation.
qualified : ExecutionClaim -> String -> Observation -> Bool
qualified c req o =
  o.obligation == req
  && o.subject == c.subject
  && o.revision == c.revision
  && o.checker /= ""
  && o.receipt /= ""
  && o.attempt /= ""
  && o.delivery /= ""
  && not o.retracted
  && (case (o.stage, o.outcome) of
        (Substantive, Succeeded) => True
        _ => False)

checkRequired : ExecutionClaim -> String -> Decision
checkRequired c req =
  if not (elem req c.scheduled) then Denied NotScheduled
  else case filter (\o => o.obligation == req) c.observations of
    [] => if null c.observations
             || any (\o => elem o.obligation c.required) c.observations
             then Void "no observation for required test"
             else Denied WrongObligation
    found =>
      if any isUnknownChecker found then Denied UnknownChecker
      else if any isUnavailable found then Void "required checker unavailable"
      else if any (\o => o.retracted) found then Denied RetractedEvidence
      else if any (\o => o.subject /= c.subject || o.revision /= c.revision) found
        then Denied StaleSubject
      else if any isSkipped found then Denied RequiredSkipped
      else if any isSetupFailure found then Denied SetupFailure
      else if any isFailed found then
        if c.summaryGreen then Denied FailedValidatorWrappedGreen
        else Denied ValidatorFailure
      else if all isSetup found then Denied SetupOnly
      else let good = filter (qualified c req) found in
        if null good then Void "no completed, attributable substantive receipt"
        else if (length (nub (map (\o => o.attempt) good)) < c.minIndependent)
             || (length (nub (map (\o => o.delivery) good)) < c.minIndependent)
             || (length (nub (map (\o => o.receipt) good)) < c.minIndependent)
          then Denied DuplicateDelivery
          else Candidate

checkAll : ExecutionClaim -> List String -> Decision
checkAll c [] = Candidate
checkAll c (req :: rest) =
  case checkRequired c req of
    Candidate => checkAll c rest
    other => other

-- The only admission path traverses every nonempty mandatory obligation.
-- A harness failure is a harness finding, not a subject-validation failure.
||| Classify a reported execution claim. After claim-wide checks, return the
||| first denial or void result in required-obligation order. Candidate requires
||| each obligation to be scheduled and the counts of distinct attempt, delivery
||| and receipt IDs in qualifying observations each to meet the confirmation
||| threshold. These IDs are not authenticated.
public export
adjudicate : ExecutionClaim -> Decision
adjudicate c =
  if null c.required then Denied EmptyRequiredSet
  else if c.jobCount == 0 then Denied ZeroJobs
  else if c.minIndependent == 0 then Denied ZeroConfirmationThreshold
  else if any isHarnessFailure c.observations then Denied HarnessFailure
  else checkAll c c.required


-- =============================================================================
-- ACTUALLY CHECKED, NARROW MATHEMATICAL OBLIGATIONS
-- =============================================================================
-- These are total proofs about the structural adjudicator. They do NOT prove
-- receipt authenticity, checker trust, completeness of CI observations or
-- the generic implication that Candidate guarantees execution in the world.
-- The presence of any arbitrary claim details cannot make an empty required
-- set or a zero-job execution admissible.

||| An empty required set is denied regardless of the other claim fields.
public export
emptyRequiredDenied :
  (subject, revision : String) ->
  (scheduled : List String) ->
  (jobs, confirmations : Nat) ->
  (observed : List Observation) ->
  (green : Bool) ->
  adjudicate (MkExecutionClaim subject revision [] scheduled
                jobs confirmations observed green) = Denied EmptyRequiredSet
emptyRequiredDenied subject revision scheduled jobs confirmations observed green = Refl

||| A claim with one required obligation and zero jobs is denied.
public export
zeroJobDenied :
  (subject, revision, obligation : String) ->
  (scheduled : List String) ->
  (confirmations : Nat) ->
  (observed : List Observation) ->
  (green : Bool) ->
  adjudicate (MkExecutionClaim subject revision [obligation] scheduled
                0 confirmations observed green) = Denied ZeroJobs
zeroJobDenied subject revision obligation scheduled confirmations observed green = Refl

-- This narrower theorem says a single failed harness observation is
-- classified as a harness failure, regardless of the green summary bit.
-- Composition with arbitrary other observations needs an additional lemma.
||| A claim with one required obligation, one job, a threshold of one and a
||| single failed harness observation is denied as a harness failure, regardless
||| of the summary or retraction flags.
public export
singleHarnessFaultDenied :
  (subject, revision, obligation, checker, receipt, attempt, delivery : String) ->
  (scheduled : List String) ->
  (green, withdrawn : Bool) ->
  adjudicate (MkExecutionClaim subject revision [obligation] scheduled 1 1
    [MkObservation obligation subject revision checker Harness FailedCheck
       receipt attempt delivery withdrawn] green) = Denied HarnessFailure
singleHarnessFaultDenied subject revision obligation checker receipt attempt delivery
                         scheduled green withdrawn = Refl
