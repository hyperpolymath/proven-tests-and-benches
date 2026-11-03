-- SPDX-License-Identifier: MPL-2.0
-- SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
module ExecutionTruthTests.Checks

import ProvenTests.Types
import ProvenTests.Framework
import ProvenTests.Classification
import ProvenTests.ExecutionTruth
import ExecutionTruthTests.Fixtures

%default total

-- These checks are Unproven: exercising an Idris2 function on committed
-- examples is NOT a universal soundness theorem or an external CI receipt.
cases : List Denial
cases =
  [ NotScheduled, ZeroJobs, SetupOnly, SetupFailure, RequiredSkipped, StaleSubject
  , FailedValidatorWrappedGreen, UnknownChecker, WrongObligation
  , DuplicateDelivery, RetractedEvidence, EmptyRequiredSet, HarnessFailure
  , ZeroConfirmationThreshold, ValidatorFailure
  ]

testCase : Denial -> IO TestResult
testCase expected =
  case (adjudicate silence, adjudicate (plant expected), adjudicate voidControl) of
    (Candidate, Denied actual, Void _) =>
      if actual == expected then pure Passed
      else pure (Failed ("wrong defect class: expected " ++ show expected
                          ++ ", received " ++ show actual))
    (clean, firing, noRun) =>
      pure (Failed ("silence/firing/void violation: "
                    ++ show clean ++ " / " ++ show firing ++ " / " ++ show noRun))

makeTest : Denial -> UnprovenTest
makeTest defect =
  let name = "execution-truth-" ++ show defect
      source = OnDisk "tests/ExecutionTruthTests/Fixtures.idr"
      pair = MkFixturePair
               (MkSilenceFixture source "same subject/revision, executed passing validator with receipt")
               (MkFiringFixture source (show defect))
      meta = classifyUnproven (MkTestId "ExecutionTruthTests.Checks" name 0)
               ("Execution truth: " ++ show defect) (Fixtures pair)
      metaWithCoord = { category := Just ReflexiveTest, aspect := Just Dependability } meta
  in MkUnprovenTest metaWithCoord (testCase defect)

public export
allExecutionTruthTests : List UnprovenTest
-- Each of these explicitly checks the silence/firing/void triad.
expectVoid : ExecutionClaim -> IO TestResult
expectVoid specimen =
  case (adjudicate silence, adjudicate specimen, adjudicate voidControl) of
    (Candidate, Void _, Void _) => pure Passed
    (clean, firing, missing) =>
      pure (Failed ("void-control violation: " ++ show clean ++ " / "
                    ++ show firing ++ " / " ++ show missing))

expectReplayDenied : IO TestResult
expectReplayDenied =
  case (adjudicate silence, adjudicate deliveryReplayedWithNewAttempt,
        adjudicate voidControl) of
    (Candidate, Denied DuplicateDelivery, Void _) => pure Passed
    (clean, firing, missing) =>
      pure (Failed ("replay-control violation: " ++ show clean ++ " / "
                    ++ show firing ++ " / " ++ show missing))

makeControl : String -> IO TestResult -> UnprovenTest
makeControl name action =
  let source = OnDisk "tests/ExecutionTruthTests/Fixtures.idr"
      pair = MkFixturePair
               (MkSilenceFixture source "clean candidate for the identical required obligation")
               (MkFiringFixture source name)
      meta = classifyUnproven (MkTestId "ExecutionTruthTests.Checks" name 0)
               ("Execution truth additional control: " ++ name) (Fixtures pair)
      located = { category := Just ReflexiveTest, aspect := Just Dependability } meta
  in MkUnprovenTest located action

public export
allExecutionTruthTests : List UnprovenTest
allExecutionTruthTests =
  map makeTest cases ++
    [ makeControl "partial-required-is-void" (expectVoid partialRequired)
    , makeControl "unavailable-checker-is-void" (expectVoid knownUnavailable)
    , makeControl "new-attempt-same-delivery-replay" expectReplayDenied
    ]
