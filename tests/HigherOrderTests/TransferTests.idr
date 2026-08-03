-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module HigherOrderTests.TransferTests

import ProvenTests.HigherOrder.Transfer
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- TRANSFER LAW TESTS - EXECUTABLE
-- =============================================================================
-- Note the asymmetry deliberately encoded below: intStringTransfer is asserted
-- ONLY in the direction that holds. Asserting the reverse round trip would be
-- false ("007" and "7" both parse to 7), and a test that asserts something
-- false is worse than a missing test.

private
transferTestId : Nat -> TestId
transferTestId n =
  MkTestId "ProvenTests.HigherOrder.TransferTests" ("test_" ++ show n) n

public export
testRoundTripInt : ProvisionallyProvenTest
testRoundTripInt =
  provisionalTest (transferTestId 1) "backward . forward = id (Int via String)" (
    assertTrue (roundTripAt intStringTransfer 42)
      "Int -> String -> Int should return the original value"
  )

public export
testRoundTripNegative : ProvisionallyProvenTest
testRoundTripNegative =
  provisionalTest (transferTestId 2) "Round trip holds for negatives" (
    assertTrue (roundTripAt intStringTransfer (-99))
      "A negative Int should survive the round trip"
  )

public export
testNegateIsIsomorphism : ProvisionallyProvenTest
testNegateIsIsomorphism =
  provisionalTest (transferTestId 3) "negate is a genuine isomorphism" (
    assertTrue (isomorphismAt negateTransfer 17 (-17))
      "Negation should round-trip in both directions"
  )

public export
testComposeIdentity : ProvisionallyProvenTest
testComposeIdentity =
  provisionalTest (transferTestId 4) "identity transfer is a unit for composition" (
    assertTrue (composeIdentityAt negateTransfer 5)
      "Composing with the identity transfer should change nothing"
  )

public export
testPreservesLength : ProvisionallyProvenTest
testPreservesLength =
  provisionalTest (transferTestId 5) "A transfer preserves list length" (
    assertTrue (transferPreservesLength intStringTransfer exampleInts)
      "Transferring elementwise should not change the number of elements"
  )

public export
allTransferTests : List ProvisionallyProvenTest
allTransferTests = [
    testRoundTripInt,
    testRoundTripNegative,
    testNegateIsIsomorphism,
    testComposeIdentity,
    testPreservesLength
  ]
