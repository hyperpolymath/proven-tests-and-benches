-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.DyadicTests

import ProvenTests.TypeSafe.Dyadic
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- DYADIC TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================


-- Helper: Create test ID for dyadic tests
private
dyadicTestId : Nat -> TestId
dyadicTestId n = MkTestId "ProvenTests.TypeSafe.DyadicTests" ("test_" ++ show n) n

-- Test: Relation is reflexive
public export
testRelationReflexive : Test ProvisionallyProven
testRelationReflexive = 
  provisionalTest (dyadicTestId 1) "Relation is reflexive" (
    assertTrue (relationReflexive equalityRelation 42) 
      "Equality relation should be reflexive"
  )

-- Test: Relation is symmetric
public export
testRelationSymmetric : Test ProvisionallyProven
testRelationSymmetric = 
  provisionalTest (dyadicTestId 2) "Relation is symmetric" (
    assertTrue (relationSymmetric equalityRelation 1 2) 
      "Equality relation should be symmetric"
  )

-- Test: Relation is transitive
public export
testRelationTransitive : Test ProvisionallyProven
testRelationTransitive = 
  provisionalTest (dyadicTestId 3) "Relation is transitive" (
    assertTrue (relationTransitive equalityRelation 1 2 3) 
      "Equality relation should be transitive"
  )

-- Test: Relation is equivalence
public export
testRelationIsEquivalence : Test ProvisionallyProven
testRelationIsEquivalence = 
  provisionalTest (dyadicTestId 4) "Relation is equivalence" (
    assertTrue (relationIsEquivalence equalityRelation) 
      "Equality relation should be an equivalence relation"
  )

-- Test: All dyadic tests pass
public export
testDyadicAllTestsPass : Test ProvisionallyProven
testDyadicAllTestsPass = 
  provisionalTest (dyadicTestId 5) "All dyadic tests pass" (
    assertTrue (runDyadicTests) 
      "All dyadic type tests should pass"
  )

-- All dyadic tests
public export
allDyadicTests : List (Test ProvisionallyProven)
allDyadicTests = [
    testRelationReflexive,
    testRelationSymmetric,
    testRelationTransitive,
    testRelationIsEquivalence,
    testDyadicAllTestsPass
  ]
