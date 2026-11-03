-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
--
-- Committed, directly compiled silence / firing / void specimens. The
-- checker does not author its own expected verdict. The firing cases are
-- planted faults in a separate module, independent of the adjudicator.
module ExecutionTruthTests.Fixtures

import ProvenTests.ExecutionTruth

%default total

public export
goodObservation : Observation
goodObservation =
  MkObservation "required-validator" "subject-A" "revision-A"
    "validator-v1" Substantive Succeeded "receipt-A" "attempt-A" "delivery-A" False

public export
silence : ExecutionClaim
silence =
  MkExecutionClaim "subject-A" "revision-A"
    ["required-validator"] ["required-validator"] 1 1 [goodObservation] True

-- The explicit not-run control is NOT a passing fixture.
public export
voidControl : ExecutionClaim
voidControl = { observations := [] } silence

public export
plant : Denial -> ExecutionClaim
plant NotScheduled = { scheduled := [] } silence
plant ZeroJobs = { jobCount := 0 } silence
plant SetupOnly =
  { observations := [{ stage := Setup } goodObservation] } silence
plant SetupFailure =
  { observations := [goodObservation, { stage := Setup, outcome := FailedCheck } goodObservation] } silence
plant RequiredSkipped =
  { observations := [{ outcome := WasSkipped } goodObservation] } silence
plant StaleSubject =
  { observations := [{ revision := "old-revision" } goodObservation] } silence
plant FailedValidatorWrappedGreen =
  { observations := [{ outcome := FailedCheck } goodObservation] } silence
plant UnknownChecker =
  { observations := [{ checker := "" } goodObservation] } silence
plant WrongObligation =
  { observations := [{ obligation := "unrelated-validator" } goodObservation] } silence
plant DuplicateDelivery =
  { minIndependent := 2
  , observations := [goodObservation, { attempt := "attempt-B" } goodObservation]
  } silence
plant RetractedEvidence =
  { observations := [{ retracted := True } goodObservation] } silence
plant EmptyRequiredSet = { required := [] } silence
plant HarnessFailure =
  { observations := [ goodObservation
                    , { stage := Harness, outcome := FailedCheck } goodObservation
                    ] } silence
-- Controls for all additional distinct machine-level denial states.
plant ZeroConfirmationThreshold = { minIndependent := 0 } silence
plant ValidatorFailure =
  { summaryGreen := False
  , observations := [{ outcome := FailedCheck } goodObservation]
  } silence

-- Extra committed adversarial cases for partial execution and unavailable
-- checkers. Every one is exercised beside the clean/void controls.
public export
partialRequired : ExecutionClaim
partialRequired =
  { required := ["required-validator", "second-validator"]
  , scheduled := ["required-validator", "second-validator"]
  } silence

public export
knownUnavailable : ExecutionClaim
knownUnavailable =
  { observations := [{ outcome := WasUnavailable } goodObservation] } silence

public export
deliveryReplayedWithNewAttempt : ExecutionClaim
deliveryReplayedWithNewAttempt =
  { minIndependent := 2
  , observations := [goodObservation, { attempt := "attempt-B" } goodObservation]
  } silence
