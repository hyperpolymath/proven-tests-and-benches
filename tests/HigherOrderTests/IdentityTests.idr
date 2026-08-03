-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module HigherOrderTests.IdentityTests

import ProvenTests.HigherOrder.Identity
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- IDENTITY LAW TESTS - EXECUTABLE
-- =============================================================================

private
identityTestId : Nat -> TestId
identityTestId n =
  MkTestId "ProvenTests.HigherOrder.IdentityTests" ("test_" ++ show n) n

public export
testLeftIdentity : ProvisionallyProvenTest
testLeftIdentity =
  provisionalTest (identityTestId 1) "id . f = f" (
    assertTrue (leftIdentityAt exampleIncrement 41)
      "Composing id on the left should not change the function"
  )

public export
testRightIdentity : ProvisionallyProvenTest
testRightIdentity =
  provisionalTest (identityTestId 2) "f . id = f" (
    assertTrue (rightIdentityAt exampleIncrement 41)
      "Composing id on the right should not change the function"
  )

public export
testIdentityBothSides : ProvisionallyProvenTest
testIdentityBothSides =
  provisionalTest (identityTestId 3) "Both identity laws hold together" (
    assertTrue (identityBothSidesAt exampleDouble 21)
      "id should be a two-sided identity for composition"
  )

public export
testIdentityIdempotent : ProvisionallyProvenTest
testIdentityIdempotent =
  provisionalTest (identityTestId 4) "id . id = id" (
    assertTrue (identityIdempotentAt (the Int 7))
      "id composed with itself should still be id"
  )

public export
testFunctorIdentityList : ProvisionallyProvenTest
testFunctorIdentityList =
  provisionalTest (identityTestId 5) "map id = id (List)" (
    assertTrue (functorIdentityList exampleInts)
      "The List functor should satisfy the identity law"
  )

public export
testFunctorIdentityMaybe : ProvisionallyProvenTest
testFunctorIdentityMaybe =
  provisionalTest (identityTestId 6) "map id = id (Maybe)" (
    assertTrue (functorIdentityMaybe (Just (the Int 9)))
      "The Maybe functor should satisfy the identity law"
  )

public export
testFunctorIdentityNothing : ProvisionallyProvenTest
testFunctorIdentityNothing =
  provisionalTest (identityTestId 7) "map id = id (Nothing)" (
    assertTrue (functorIdentityMaybe (the (Maybe Int) Nothing))
      "The identity law should hold on the empty case too"
  )

public export
testFunctorComposition : ProvisionallyProvenTest
testFunctorComposition =
  provisionalTest (identityTestId 8) "map (g . f) = map g . map f" (
    assertTrue (functorCompositionList exampleDouble exampleIncrement exampleInts)
      "The List functor should satisfy the composition law"
  )

public export
allIdentityTests : List ProvisionallyProvenTest
allIdentityTests = [
    testLeftIdentity,
    testRightIdentity,
    testIdentityBothSides,
    testIdentityIdempotent,
    testFunctorIdentityList,
    testFunctorIdentityMaybe,
    testFunctorIdentityNothing,
    testFunctorComposition
  ]
