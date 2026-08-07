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

-- Example relations
public export
equalityRelation : Relation Nat
equalityRelation = MkRelation "Equality" (==) True True True

-- NOTE: this DECLARES `reflexive = True` for (<), which is false at every
-- point (`x < x` never holds). It is kept deliberately as a negative fixture:
-- `declaredFlagsHonest` must reject it. Until 2026-08-07 nothing did, because
-- the only predicate that looked at the flags trusted them.
public export
lessThanRelation : Relation Nat
lessThanRelation = MkRelation "Less Than" (<) True False True

public export
alwaysTrueRelation : Relation Nat
alwaysTrueRelation = MkRelation "Always True" (\_, _ => True) True True True

-- A relation declaring all three properties that (<) has none of. Every
-- conjunct of `declaredFlagsHonest` must reject it.
public export
overclaimingRelation : Relation Nat
overclaimingRelation = MkRelation "Overclaiming <" (<) True True True

-- =============================================================================
-- HOLDING DECLARATIONS TO BEHAVIOUR
-- =============================================================================
-- `MkRelation` lets a caller declare reflexivity, symmetry and transitivity
-- without exhibiting any of them. The witness sets below are the points at
-- which a declaration is checked against what `relates` actually does.
--
-- Absence of a counterexample on a finite set is not a proof, and this does not
-- claim to be one. It catches false DECLARATIONS — which is the failure mode
-- the record permits.

public export
dyadicWitnesses : List Nat
dyadicWitnesses = [0, 1, 2, 5, 42]

public export
dyadicPairs : List (Nat, Nat)
dyadicPairs = [(0, 0), (1, 1), (2, 2), (1, 2), (2, 1), (5, 42)]

public export
dyadicTriples : List (Nat, Nat, Nat)
dyadicTriples = [(2, 2, 2), (1, 1, 1), (1, 2, 3), (5, 5, 5), (0, 0, 0), (1, 1, 2)]

--/ No declared property may be contradicted on the witness set.
--/
--/ NOTE (2026-08-07): `relationIsEquivalence` used to read the three
--/ self-declared boolean flags and nothing else — `(MkRelation _ _ r s t) =
--/ r && s && t`. `lessThanRelation` declares `reflexive = True` for (<) and no
--/ test caught it, because no test ever compared a declaration with behaviour.
public export
declaredFlagsHonest : Relation Nat -> Bool
declaredFlagsHonest r =
     (not (reflexive r)  || all (\x => relates r x x) dyadicWitnesses)
  && (not (symmetric r)  || all (\(x, y) => relates r x y == relates r y x) dyadicPairs)
  && (not (transitive r) || all (\(x, y, z) =>
        not (relates r x y && relates r y z) || relates r x z) dyadicTriples)

-- Test: Relation is equivalence (declared reflexive + symmetric + transitive,
-- and none of those declarations contradicted by behaviour). The declaration
-- alone is not enough; that was the previous implementation.
public export
relationIsEquivalence : Relation Nat -> Bool
relationIsEquivalence r =
  reflexive r && symmetric r && transitive r && declaredFlagsHonest r

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

-- NOTE (2026-08-07): three of the four entries here used to ignore their
-- argument and re-apply a hardcoded `equalityRelation`, and — worse — they
-- called the predicates at points where the antecedent is FALSE:
--
--   relationSymmetric  equalityRelation 1 2    -- rel 1 2 = False, so this
--                                              -- compares False with False
--   relationTransitive equalityRelation 1 2 3  -- rel 1 2 && rel 2 3 = False,
--                                              -- so `not (...) || rel x z`
--                                              -- short-circuits to True and
--                                              -- the consequent is never
--                                              -- evaluated
--
-- Both passed for the wrong reason: the implications were vacuously true and a
-- broken `relates` would not have been detected. The entries below are
-- parametric in the relation and discharge their antecedents.
public export
dyadicTests : List (Relation Nat -> Bool)
dyadicTests = [
    -- reflexivity at a witness
    (\r => relationReflexive r 42),
    -- symmetry where the relation HOLDS, so True is compared with True
    (\r => relationSymmetric r 2 2),
    -- ...and where it does not, so both directions are exercised
    (\r => relationSymmetric r 1 2),
    -- transitivity with the antecedent DISCHARGED: under (==), rel 2 2 &&
    -- rel 2 2 is True, so the consequent rel 2 2 must actually be evaluated
    (\r => relationTransitive r 2 2 2),
    relationIsEquivalence,
    declaredFlagsHonest
  ]

-- =============================================================================
-- NEGATIVE FIXTURES
-- =============================================================================
-- A suite containing only cases that pass cannot distinguish a working checker
-- from one that returns True. These must be REJECTED.

--/ Declares reflexivity for (<), which is false at every point.
public export
dishonestRelationRejected : Bool
dishonestRelationRejected = not (declaredFlagsHonest lessThanRelation)

--/ Declares all three properties for (<), which has none of them.
public export
overclaimingRelationRejected : Bool
overclaimingRelationRejected = not (declaredFlagsHonest overclaimingRelation)

--/ ...and is therefore not an equivalence relation either.
public export
overclaimingNotEquivalence : Bool
overclaimingNotEquivalence = not (relationIsEquivalence overclaimingRelation)

-- Run all dyadic tests: the parametric suite against a relation that genuinely
-- is an equivalence, a second honest relation, and the negative fixtures.
public export
runDyadicTests : Bool
runDyadicTests =
     all (\f => f equalityRelation) dyadicTests
  && declaredFlagsHonest alwaysTrueRelation
  && dishonestRelationRejected
  && overclaimingRelationRejected
  && overclaimingNotEquivalence

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
