-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
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

-- Test: Dependent pair maintains type correctness.
--
-- NOTE (2026-08-07): this is TRUE BY CONSTRUCTION. `MkDepPair` is the only
-- constructor of `DepPair`, so the single clause is total and the result is a
-- constant. It is not a runtime check and must not be read as one — the content
-- is carried by the type index, which the compiler enforced before this
-- function ran. It is kept because the *signature* is the assertion, and
-- labelled here rather than dressed up as a test that could fail.
--
-- The same applies to `vectHeadSafe` below. `vectLengthMatchesIndex` is the one
-- predicate in this module that can genuinely fail; see its note.
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

-- Test: Vect head is safe (no runtime error).
--
-- NOTE: also true by construction — the index `S n` already forbids `Nil`, so
-- the single clause is exhaustive. There is no unsafe case for this to reach.
-- The safety is the type's, not this function's.
public export
vectHeadSafe : Vect Nat (S n) -> Bool
vectHeadSafe (x :: _) = True

-- Erase the length index down to a runtime spine.
public export
vectToList : Vect a n -> List a
vectToList Nil = []
vectToList (x :: xs) = x :: vectToList xs

--/ The runtime length agrees with the type-level index.
--/
--/ This is the one predicate here that can actually fail: it crosses the
--/ erasure boundary, so a `vectToList` that dropped or duplicated an element
--/ would be caught. The type-level guarantees above cannot be tested at
--/ runtime — this checks that the erased representation still honours them.
public export
vectLengthMatchesIndex : (n : Nat) -> Vect Nat n -> Bool
vectLengthMatchesIndex n v = length (vectToList v) == n

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
    (\_ => dependentPairCorrect testDepPair),   -- true by construction (see note)
    (\v => vectLengthCorrect v),
    (\v => vectHeadSafe v),                     -- true by construction (see note)
    (\v => dependentInvariant 3 v),
    (\v => vectLengthMatchesIndex 3 v)          -- crosses the erasure boundary
  ]

public export
testVect5 : Vect Nat 5
testVect5 = 1 :: 2 :: 3 :: 4 :: 5 :: Nil

--/ The length of the erased spine.
public export
erasedLength : Vect Nat n -> Nat
erasedLength v = length (vectToList v)

--/ The erased spine carries the length its index claims, and that measurement
--/ DISCRIMINATES — it returns 5 for a five-element vector and not 3.
--/
--/ NOTE (2026-08-07): the negative case is stated over `Nat` deliberately. The
--/ obvious formulation, `not (vectLengthMatchesIndex 3 testVect5)`, does not
--/ compile: the index makes the mismatched call *unrepresentable*
--/ ("Mismatch between: 2 and 0"). That is the guarantee this module exists to
--/ document — and it is also the reason no runtime test here can fail. The
--/ compiler rejected the counterexample before it could be run, which is a
--/ stronger result than a passing assertion, and a weaker basis for calling
--/ these "tests".
public export
lengthIndexDistinguishes : Bool
lengthIndexDistinguishes =
     erasedLength testVect  == 3
  && erasedLength testVect5 == 5
  && not (erasedLength testVect5 == 3)

-- Run all dependent tests, plus the witness that the length check discriminates.
public export
runDependentTests : Bool
runDependentTests =
  all (\f => f testVect) dependentTests && lengthIndexDistinguishes

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
