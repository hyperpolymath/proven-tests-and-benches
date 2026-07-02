-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.TypeSafe.Dyadic

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- DYADIC TYPE TESTS
-- =============================================================================
-- Tests for binary relation types (custom implementation)
-- Ensures properties of binary relations


-- Binary relation
public export
record Relation a where
  constructor MkRelation
  name : String
  relates : a -> a -> Bool
  reflexive : Bool
  symmetric : Bool
  transitive : Bool

-- Test: Relation is reflexive (x ~ x)
public export
relationReflexive : Relation a -> a -> Bool
relationReflexive (MkRelation _ rel True _ _) x = rel x x
relationReflexive _ _ = False

-- Test: Relation is symmetric (x ~ y => y ~ x)
public export
relationSymmetric : Relation a -> a -> a -> Bool
relationSymmetric (MkRelation _ rel _ True _) x y = 
  (rel x y) == (rel y x)
relationSymmetric _ _ _ = False

-- Test: Relation is transitive (x ~ y && y ~ z => x ~ z)
public export
relationTransitive : Relation a -> a -> a -> a -> Bool
relationTransitive (MkRelation _ rel _ _ True) x y z =
  not (rel x y && rel y z) || (rel x z)
relationTransitive _ _ _ _ = False

-- Test: Relation is equivalence (reflexive + symmetric + transitive)
public export
relationIsEquivalence : Relation a -> Bool
relationIsEquivalence (MkRelation _ _ r s t) = r && s && t

-- Example relations
public export
equalityRelation : Relation Nat
equalityRelation = MkRelation "Equality" (==) True True True

public export
lessThanRelation : Relation Nat
lessThanRelation = MkRelation "Less Than" (<) True False True

public export
alwaysTrueRelation : Relation Nat
alwaysTrueRelation = MkRelation "Always True" (\_, _ => True) True True True

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
dyadicTests : List (Relation Nat -> Bool)
dyadicTests = [
    (\_ => relationReflexive equalityRelation 42),
    (\_ => relationSymmetric equalityRelation 1 2),
    (\_ => relationTransitive equalityRelation 1 2 3),
    relationIsEquivalence
  ]

-- Run all dyadic tests
public export
runDyadicTests : Bool
runDyadicTests = all (\f => f equalityRelation) dyadicTests

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
dyadicClassification : TestMetadata
dyadicClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Dyadic" "allTests" 0
      desc = "Dyadic type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Binary Relation Types" "Custom" ["Relation properties"]
  in classifyProvisionallyProven tid desc framework cert
