-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module TypeSafeTests.DyadicTests

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
testRelationReflexive : ProvisionallyProvenTest
testRelationReflexive = 
  provisionalTest (dyadicTestId 1) "Relation is reflexive" (
    assertTrue (relationReflexive equalityRelation 42) 
      "Equality relation should be reflexive"
  )

-- Test: Relation is symmetric
-- Called at (2,2), where the relation HOLDS, so `rel x y == rel y x` compares
-- True with True. At (1,2) — as this test read until 2026-08-07 — it compared
-- False with False and passed without ever touching the symmetric case.
public export
testRelationSymmetric : ProvisionallyProvenTest
testRelationSymmetric =
  provisionalTest (dyadicTestId 2) "Relation is symmetric (antecedent discharged)" (
    assertTrue (relationSymmetric equalityRelation 2 2)
      "Equality relation should be symmetric where it holds"
  )

-- Test: Relation is transitive
-- Called at (2,2,2), where `rel x y && rel y z` is TRUE, so the consequent
-- `rel x z` must actually be evaluated. At (1,2,3) the antecedent is False and
-- the implication `not (...) || rel x z` short-circuits to True — vacuously.
public export
testRelationTransitive : ProvisionallyProvenTest
testRelationTransitive =
  provisionalTest (dyadicTestId 3) "Relation is transitive (antecedent discharged)" (
    assertTrue (relationTransitive equalityRelation 2 2 2)
      "Equality relation should be transitive where the antecedent holds"
  )

-- Test: a relation that declares a property it does not have is REJECTED.
-- `lessThanRelation` declares `reflexive = True` for (<); `x < x` never holds.
public export
testDishonestDeclarationRejected : ProvisionallyProvenTest
testDishonestDeclarationRejected =
  provisionalTest (dyadicTestId 6) "False reflexivity declaration is rejected" (
    assertTrue dishonestRelationRejected
      "lessThanRelation declares reflexivity for (<) and must be rejected"
  )

-- Test: a relation declaring all three properties it lacks is REJECTED.
public export
testOverclaimingRelationRejected : ProvisionallyProvenTest
testOverclaimingRelationRejected =
  provisionalTest (dyadicTestId 7) "Overclaiming relation is rejected" (
    assertTrue overclaimingRelationRejected
      "A relation declaring reflexive+symmetric+transitive for (<) must be rejected"
  )

-- Test: Relation is equivalence
public export
testRelationIsEquivalence : ProvisionallyProvenTest
testRelationIsEquivalence = 
  provisionalTest (dyadicTestId 4) "Relation is equivalence" (
    assertTrue (relationIsEquivalence equalityRelation) 
      "Equality relation should be an equivalence relation"
  )

-- Test: All dyadic tests pass
public export
testDyadicAllTestsPass : ProvisionallyProvenTest
testDyadicAllTestsPass = 
  provisionalTest (dyadicTestId 5) "All dyadic tests pass" (
    assertTrue (runDyadicTests) 
      "All dyadic type tests should pass"
  )

-- All dyadic tests
public export
allDyadicTests : List (ProvisionallyProvenTest)
allDyadicTests = [
    testRelationReflexive,
    testRelationSymmetric,
    testRelationTransitive,
    testRelationIsEquivalence,
    testDyadicAllTestsPass,
    testDishonestDeclarationRejected,
    testOverclaimingRelationRejected
  ]
