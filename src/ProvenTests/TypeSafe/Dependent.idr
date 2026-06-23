-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Dependent

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- DEPENDENT TYPE SYSTEM TESTS
-- =============================================================================
-- Tests for Idris2 core dependent type verification
-- Ensures type correctness with dependent types


-- Dependent pair: value depends on type
public export
data DepPair : (t : Type) -> t -> Type where
  MkDepPair : (t : Type) -> (v : t) -> DepPair t v

-- Test: Dependent pair maintains type correctness
public export
dependentPairCorrect : DepPair Nat n -> Bool
dependentPairCorrect (MkDepPair _ _) = True

-- Dependent list: list indexed by natural numbers
public export
data Vect : (a : Type) -> Nat -> Type where
  Nil : Vect a 0
  (::) : a -> Vect a n -> Vect a (S n)

-- Test: Vect length matches index
public export
vectLengthCorrect : Vect Nat 3 -> Bool
vectLengthCorrect (x :: y :: z :: Nil) = True
vectLengthCorrect _ = False

-- Test: Vect head is safe (no runtime error)
public export
vectHeadSafe : Vect Nat (S n) -> Bool
vectHeadSafe (x :: _) = True

-- Test: Dependent type preserves invariants
public export
dependentInvariant : (x : Nat) -> Vect Nat x -> Bool
dependentInvariant 0 Nil = True
dependentInvariant (S n) (x :: xs) = dependentInvariant n xs
dependentInvariant _ _ = False

-- Test data
public export
testDepPair : DepPair Nat 42
testDepPair = MkDepPair Nat 42

public export
testVect : Vect Nat 3
testVect = 1 :: 2 :: 3 :: Nil

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
dependentTests : List (Vect Nat 3 -> Bool)
dependentTests = [
    (\_ => dependentPairCorrect testDepPair),
    (\v => vectLengthCorrect v),
    (\v => vectHeadSafe v),
    (\v => dependentInvariant 3 v)
  ]

-- Run all dependent tests
public export
runDependentTests : Bool
runDependentTests = all (\f => f testVect) dependentTests

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
dependentClassification : TestMetadata
dependentClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Dependent" "allTests" 0
      desc = "Dependent type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Idris2 Dependent Types" "Idris2 core" ["Type correctness"]
  in classifyProvisionallyProven tid desc framework cert
