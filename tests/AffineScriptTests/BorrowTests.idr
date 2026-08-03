-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module AffineScriptTests.BorrowTests

import ProvenTests.AffineScript.Borrow
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- BORROW TESTS - EXECUTABLE
-- =============================================================================
-- Guarantees 2 and 3 of affinescript/lib/borrow.ml: "No conflicting borrows"
-- and "Borrows don't outlive owners".
--
-- As in AffinityTests, the rejection cases carry the weight: a checker that
-- accepts everything passes every acceptance test.

private
borrowTestId : Nat -> TestId
borrowTestId n =
  MkTestId "ProvenTests.AffineScript.BorrowTests" ("test_" ++ show n) n

-- --- Guarantee 2: no conflicting borrows --------------------------------------

public export
testSharedCoexist : ProvisionallyProvenTest
testSharedCoexist =
  provisionalTest (borrowTestId 1) "Many shared borrows may coexist" (
    assertTrue sharedBorrowsCoexist
      "Overlapping shared borrows of one place are allowed"
  )

public export
testExclusiveExcludesShared : ProvisionallyProvenTest
testExclusiveExcludesShared =
  provisionalTest (borrowTestId 2) "Exclusive excludes shared — REJECTED" (
    assertTrue exclusiveExcludesShared
      "An exclusive borrow must exclude an overlapping shared borrow"
  )

public export
testTwoExclusivesConflict : ProvisionallyProvenTest
testTwoExclusivesConflict =
  provisionalTest (borrowTestId 3) "Two exclusives conflict — REJECTED" (
    assertTrue twoExclusivesConflict
      "Two overlapping exclusive borrows of one place must conflict"
  )

public export
testDifferentPlacesFine : ProvisionallyProvenTest
testDifferentPlacesFine =
  provisionalTest (borrowTestId 4) "Different places never conflict" (
    assertTrue differentPlacesDoNotConflict
      "Exclusive borrows of distinct places are independent"
  )

public export
testDisjointLifetimesFine : ProvisionallyProvenTest
testDisjointLifetimesFine =
  provisionalTest (borrowTestId 5) "Disjoint lifetimes never conflict" (
    assertTrue disjointLifetimesDoNotConflict
      "Sequential exclusive borrows of one place are allowed"
  )

public export
testConflictSymmetric : ProvisionallyProvenTest
testConflictSymmetric =
  provisionalTest (borrowTestId 6) "Conflict is symmetric" (
    assertTrue (conflictSymmetric sharedA exclusiveB)
      "conflicts a b should equal conflicts b a"
  )

-- --- Guarantee 3: borrows don't outlive owners --------------------------------

public export
testContainedAccepted : ProvisionallyProvenTest
testContainedAccepted =
  provisionalTest (borrowTestId 7) "A contained borrow is accepted" (
    assertTrue containedBorrowAccepted
      "A borrow inside its owner's lifetime is well-formed"
  )

public export
testEscapingRejected : ProvisionallyProvenTest
testEscapingRejected =
  provisionalTest (borrowTestId 8) "A borrow outliving its owner — REJECTED" (
    assertTrue escapingBorrowRejected
      "A borrow must not outlive the owner it borrows from"
  )

public export
testEarlyBorrowRejected : ProvisionallyProvenTest
testEarlyBorrowRejected =
  provisionalTest (borrowTestId 9) "A borrow predating its owner — REJECTED" (
    assertTrue earlyBorrowRejected
      "A borrow must not start before its owner exists"
  )

public export
allBorrowTests : List ProvisionallyProvenTest
allBorrowTests = [
    testSharedCoexist,
    testExclusiveExcludesShared,
    testTwoExclusivesConflict,
    testDifferentPlacesFine,
    testDisjointLifetimesFine,
    testConflictSymmetric,
    testContainedAccepted,
    testEscapingRejected,
    testEarlyBorrowRejected
  ]
