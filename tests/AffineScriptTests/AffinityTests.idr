-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module AffineScriptTests.AffinityTests

import ProvenTests.AffineScript.Affinity
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- AFFINITY TESTS - EXECUTABLE
-- =============================================================================
-- Guarantee 1 of affinescript/lib/borrow.ml: "No use after move".
--
-- Half of these assert that a VIOLATION is detected. A suite that only checks
-- the happy path would pass just as well against a checker that accepts
-- everything.

private
affinityTestId : Nat -> TestId
affinityTestId n =
  MkTestId "ProvenTests.AffineScript.AffinityTests" ("test_" ++ show n) n

public export
testDropIsAffine : ProvisionallyProvenTest
testDropIsAffine =
  provisionalTest (affinityTestId 1) "Dropping a value is affine (0 uses)" (
    assertTrue (dropIsAffine varX)
      "An affine value may be dropped without being used"
  )

public export
testSingleUseIsAffine : ProvisionallyProvenTest
testSingleUseIsAffine =
  provisionalTest (affinityTestId 2) "Using once is affine" (
    assertTrue (singleUseIsAffine varX)
      "One use should satisfy affinity"
  )

public export
testDoubleUseRejected : ProvisionallyProvenTest
testDoubleUseRejected =
  provisionalTest (affinityTestId 3) "Using twice is REJECTED" (
    assertTrue (doubleUseIsRejected varX)
      "Two uses should violate affinity — if this fails the check is vacuous"
  )

public export
testAffineWeakerThanLinear : ProvisionallyProvenTest
testAffineWeakerThanLinear =
  provisionalTest (affinityTestId 4) "Affine is weaker than linear" (
    assertTrue (affineIsWeakerThanLinear varX)
      "Dropping satisfies affine but not linear — the two must not be conflated"
  )

public export
testUseAfterMoveRejected : ProvisionallyProvenTest
testUseAfterMoveRejected =
  provisionalTest (affinityTestId 5) "Use after move is REJECTED" (
    assertTrue (useAfterMoveIsRejected varX varY)
      "Using a moved-out variable should be rejected"
  )

public export
testUseOfMoveTargetAllowed : ProvisionallyProvenTest
testUseOfMoveTargetAllowed =
  provisionalTest (affinityTestId 6) "Use of the move TARGET is allowed" (
    assertTrue (useOfMoveTargetIsAllowed varX varY)
      "The destination of a move is live and may be used"
  )

public export
testUseBeforeMoveAllowed : ProvisionallyProvenTest
testUseBeforeMoveAllowed =
  provisionalTest (affinityTestId 7) "Use BEFORE move is allowed" (
    assertTrue (useBeforeMoveIsAllowed varX varY)
      "Order matters: a use preceding the move is fine"
  )

public export
testGoodTraceIsAffine : ProvisionallyProvenTest
testGoodTraceIsAffine =
  provisionalTest (affinityTestId 8) "A trace with no repeats is affine" (
    assertTrue (traceIsAffine exampleGoodTrace)
      "Distinct uses should satisfy affinity"
  )

public export
testBadTraceRejected : ProvisionallyProvenTest
testBadTraceRejected =
  provisionalTest (affinityTestId 9) "A trace with a repeat is REJECTED" (
    assertTrue (not (traceIsAffine exampleBadTrace))
      "A repeated use should violate affinity"
  )

public export
allAffinityTests : List ProvisionallyProvenTest
allAffinityTests = [
    testDropIsAffine,
    testSingleUseIsAffine,
    testDoubleUseRejected,
    testAffineWeakerThanLinear,
    testUseAfterMoveRejected,
    testUseOfMoveTargetAllowed,
    testUseBeforeMoveAllowed,
    testGoodTraceIsAffine,
    testBadTraceRejected
  ]
