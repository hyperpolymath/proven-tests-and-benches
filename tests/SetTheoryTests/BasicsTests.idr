-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module SetTheoryTests.BasicsTests

import ProvenTests.SetTheory.Basics
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- SET OPERATION TESTS - EXECUTABLE
-- =============================================================================

private
basicsTestId : Nat -> TestId
basicsTestId n =
  MkTestId "ProvenTests.SetTheory.BasicsTests" ("test_" ++ show n) n

public export
testUnionIdempotent : ProvisionallyProvenTest
testUnionIdempotent =
  provisionalTest (basicsTestId 1) "A union A = A" (
    assertTrue (unionIdempotent setA) "Union should be idempotent"
  )

public export
testIntersectIdempotent : ProvisionallyProvenTest
testIntersectIdempotent =
  provisionalTest (basicsTestId 2) "A intersect A = A" (
    assertTrue (intersectIdempotent setA) "Intersection should be idempotent"
  )

public export
testUnionCommutative : ProvisionallyProvenTest
testUnionCommutative =
  provisionalTest (basicsTestId 3) "A union B = B union A" (
    assertTrue (unionCommutative setA setB) "Union should be commutative"
  )

public export
testIntersectCommutative : ProvisionallyProvenTest
testIntersectCommutative =
  provisionalTest (basicsTestId 4) "A intersect B = B intersect A" (
    assertTrue (intersectCommutative setA setB)
      "Intersection should be commutative"
  )

public export
testUnionAssociative : ProvisionallyProvenTest
testUnionAssociative =
  provisionalTest (basicsTestId 5) "Union is associative" (
    assertTrue (unionAssociative setA setB setC) "Union should be associative"
  )

public export
testIntersectAssociative : ProvisionallyProvenTest
testIntersectAssociative =
  provisionalTest (basicsTestId 6) "Intersection is associative" (
    assertTrue (intersectAssociative setA setB setC)
      "Intersection should be associative"
  )

public export
testUnionEmptyIdentity : ProvisionallyProvenTest
testUnionEmptyIdentity =
  provisionalTest (basicsTestId 7) "A union {} = A" (
    assertTrue (unionEmptyIdentity setA)
      "The empty set should be a unit for union"
  )

public export
testIntersectEmptyAnnihilates : ProvisionallyProvenTest
testIntersectEmptyAnnihilates =
  provisionalTest (basicsTestId 8) "A intersect {} = {}" (
    assertTrue (intersectEmptyAnnihilates setA)
      "The empty set should annihilate under intersection"
  )

public export
testDistributivity : ProvisionallyProvenTest
testDistributivity =
  provisionalTest (basicsTestId 9) "Union distributes over intersection" (
    assertTrue (unionDistributesOverIntersect setA setB setC)
      "The lattice should be distributive"
  )

public export
testDifferenceSelfEmpty : ProvisionallyProvenTest
testDifferenceSelfEmpty =
  provisionalTest (basicsTestId 10) "A \\ A = {}" (
    assertTrue (differenceSelfEmpty setA)
      "A set minus itself should be empty"
  )

public export
testDeMorgan : ProvisionallyProvenTest
testDeMorgan =
  provisionalTest (basicsTestId 11) "De Morgan: U\\(A u B) = (U\\A) n (U\\B)" (
    assertTrue (deMorganUnion universe setA setB)
      "De Morgan's law should hold relative to the universe"
  )

public export
allBasicsTests : List ProvisionallyProvenTest
allBasicsTests = [
    testUnionIdempotent,
    testIntersectIdempotent,
    testUnionCommutative,
    testIntersectCommutative,
    testUnionAssociative,
    testIntersectAssociative,
    testUnionEmptyIdentity,
    testIntersectEmptyAnnihilates,
    testDistributivity,
    testDifferenceSelfEmpty,
    testDeMorgan
  ]
