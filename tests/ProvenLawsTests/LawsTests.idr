-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenLawsTests.LawsTests

import ProvenTests.Proven.Laws
import ProvenTests.Framework
import ProvenTests.Types
import Data.List1
import Data.Nat

%default total

-- =============================================================================
-- ACTUALLY-PROVEN TESTS - THE FIRST IN THIS REPO
-- =============================================================================
-- Every test here is `provenTest`, not `provisionalTest`, and each one is
-- entitled to that label because the property it names is a theorem in
-- src/ProvenTests/Proven/Laws.idr with a term inhabiting it under
-- `%default total`.
--
-- READ THIS BEFORE ADDING ONE.
--
-- The ladder is `List1 Witnessed`, and every rung here is built with
-- `ProvenTests.Types.rung`: one quoted theorem name (`{mapFusionProof}) supplies
-- both the proof term and the printed citation, checked against the law's full
-- statement. The typechecker therefore rejects a rung naming a theorem that
-- does not exist, a theorem that proves a different property, and a citation
-- that differs from the term (tests/SpecSuite/Main.idr holds those rejections
-- as `failing` blocks).
--
-- What it cannot reject is a statement that is true but is not the property
-- the test description names (`Witness s () ()` compiles). So the rule for
-- this file: the statement passed to `rung` is the law's full statement,
-- written out, never `_`. Polymorphic laws need the implicits written out in
-- order of appearance (`{0 a, b : Type} -> ...`).
--
-- The runtime body is `assertTrue True` on purpose. The property was already
-- discharged at compile time; re-checking it on one witness at run time would
-- add nothing and would misleadingly suggest the evidence is the sample. The
-- reason is written into each test's message rather than left to be inferred.

private
lawsTestId : Nat -> TestId
lawsTestId n =
  MkTestId "ProvenTests.Proven.LawsTests" ("test_" ++ show n) n

--/ The file every rung in this module cites.
private
lawsFile : Maybe String
lawsFile = Just "src/ProvenTests/Proven/Laws.idr"

private
discharged : String -> IO TestResult
discharged thm =
  assertTrue True ("discharged at compile time by " ++ thm ++ " in Laws.idr")

-- --- Identity ------------------------------------------------------------------

--/ Actually-Proven: id . f = f, for all f and x. Discharged at compile time; the rung cites the theorem.
public export
testLeftIdentity : ActuallyProvenTest
testLeftIdentity =
  provenTest (lawsTestId 1)
    "id . f = f, for all f and x"
    (discharged "leftIdentityProof")
    (singleton (rung "Definitional: (id . f) x reduces to f x"
                     lawsFile (Just 41) `{leftIdentityProof}
                     ({0 a, b : Type} -> (f : a -> b) -> (x : a) -> (Prelude.id . f) x = f x)))

--/ Actually-Proven: f . id = f, for all f and x. Discharged at compile time; the rung cites the theorem.
public export
testRightIdentity : ActuallyProvenTest
testRightIdentity =
  provenTest (lawsTestId 2)
    "f . id = f, for all f and x"
    (discharged "rightIdentityProof")
    (singleton (rung "Definitional: (f . id) x reduces to f x"
                     lawsFile (Just 46) `{rightIdentityProof}
                     ({0 a, b : Type} -> (f : a -> b) -> (x : a) -> (f . Prelude.id) x = f x)))

--/ Actually-Proven: id . id = id, for all x. Discharged at compile time; the rung cites the theorem.
public export
testIdentityIdempotent : ActuallyProvenTest
testIdentityIdempotent =
  provenTest (lawsTestId 3)
    "id . id = id, for all x"
    (discharged "identityIdempotentProof")
    (singleton (rung "Definitional"
                     lawsFile (Just 51) `{identityIdempotentProof}
                     ({0 a : Type} -> (x : a) -> (Prelude.id . Prelude.id) x = Prelude.id x)))

-- --- Functor laws ---------------------------------------------------------------

--/ Actually-Proven: map id = id, for ALL lists. Discharged at compile time; the rung cites the theorem.
public export
testMapIdentity : ActuallyProvenTest
testMapIdentity =
  provenTest (lawsTestId 4)
    "map id = id, for ALL lists"
    (discharged "mapIdentityProof")
    (singleton (rung "Induction on the list; cons case rewrites by the IH"
                     lawsFile (Just 60) `{mapIdentityProof}
                     ({0 a : Type} -> (xs : List a) -> map Prelude.id xs = xs)))

--/ Actually-Proven: map g . map f = map (g . f), for ALL lists. Discharged at compile time; the rung cites the theorem.
public export
testMapFusion : ActuallyProvenTest
testMapFusion =
  provenTest (lawsTestId 5)
    "map g . map f = map (g . f), for ALL lists"
    (discharged "mapFusionProof")
    (singleton (rung "Induction on the list"
                     lawsFile (Just 66) `{mapFusionProof}
                     ({0 b, c, a : Type} -> (g : b -> c) -> (f : a -> b) -> (xs : List a) -> map g (map f xs) = map (g . f) xs)))

--/ Actually-Proven: map preserves length, for ALL lists. Discharged at compile time; the rung cites the theorem.
public export
testMapLength : ActuallyProvenTest
testMapLength =
  provenTest (lawsTestId 6)
    "map preserves length, for ALL lists"
    (discharged "mapLengthProof")
    (singleton (rung "Induction on the list"
                     lawsFile (Just 73) `{mapLengthProof}
                     ({0 a, b : Type} -> (f : a -> b) -> (xs : List a) -> length (map f xs) = length xs)))

--/ Actually-Proven: map id = id, for ALL Maybe values. Discharged at compile time; the rung cites the theorem.
public export
testMapMaybeIdentity : ActuallyProvenTest
testMapMaybeIdentity =
  provenTest (lawsTestId 7)
    "map id = id, for ALL Maybe values"
    (discharged "mapMaybeIdentityProof")
    (singleton (rung "Case split; both cases definitional"
                     lawsFile (Just 81) `{mapMaybeIdentityProof}
                     ({0 a : Type} -> (mx : Maybe a) -> map Prelude.id mx = mx)))

-- --- Append and reverse ----------------------------------------------------------

--/ Actually-Proven: xs ++ [] = xs, for ALL lists. Discharged at compile time; the rung cites the theorem.
public export
testAppendNilRight : ActuallyProvenTest
testAppendNilRight =
  provenTest (lawsTestId 8)
    "xs ++ [] = xs, for ALL lists"
    (discharged "appendNilRightProof")
    (singleton (rung "Induction; the left unit is definitional, this is not"
                     lawsFile (Just 90) `{appendNilRightProof}
                     ({0 a : Type} -> (xs : List a) -> xs ++ [] = xs)))

--/ Actually-Proven: length (xs ++ ys) = length xs + length ys, for ALL lists. Discharged at compile time; the rung cites the theorem.
public export
testAppendLength : ActuallyProvenTest
testAppendLength =
  provenTest (lawsTestId 9)
    "length (xs ++ ys) = length xs + length ys, for ALL lists"
    (discharged "appendLengthProof")
    (singleton (rung "Induction on the first list"
                     lawsFile (Just 96) `{appendLengthProof}
                     ({0 a : Type} -> (xs : List a) -> (ys : List a) -> length (xs ++ ys) = length xs + length ys)))

--/ Actually-Proven: reverse [x] = [x], for all x. Discharged at compile time; the rung cites the theorem.
public export
testReverseSingleton : ActuallyProvenTest
testReverseSingleton =
  provenTest (lawsTestId 10)
    "reverse [x] = [x], for all x"
    (discharged "reverseSingletonProof")
    (singleton (rung "Definitional"
                     lawsFile (Just 105) `{reverseSingletonProof}
                     ({0 a : Type} -> (x : a) -> reverse [x] = [x])))

-- --- Affinity, proved rather than sampled -----------------------------------------

--/ Actually-Proven: An unused variable has use-count 0, for ALL variables. Discharged at compile time; the rung cites the theorem.
public export
testEmptyTraceUseCount : ActuallyProvenTest
testEmptyTraceUseCount =
  provenTest (lawsTestId 11)
    "An unused variable has use-count 0, for ALL variables"
    (discharged "emptyTraceUseCountProof")
    (singleton (rung "Definitional. AffinityTests checks this on one witness; here it holds for every variable."
                     lawsFile (Just 117) `{emptyTraceUseCountProof}
                     ((v : String) -> length (filter (== v) []) = 0)))

--/ Actually-Proven: A use-count never exceeds the trace length, for ALL traces. Discharged at compile time; the rung cites the theorem.
public export
testFilterLengthBound : ActuallyProvenTest
testFilterLengthBound =
  provenTest (lawsTestId 12)
    "A use-count never exceeds the trace length, for ALL traces"
    (discharged "filterLengthBoundProof")
    (singleton (rung "Induction with a with-split on the predicate; the bound that makes affinity's use-count meaningful."
                     lawsFile (Just 124) `{filterLengthBoundProof}
                     ({0 a : Type} -> (p : a -> Bool) -> (xs : List a) -> LTE (length (filter p xs)) (length xs))))

public export
allProvenLawsTests : List ActuallyProvenTest
allProvenLawsTests = [
    testLeftIdentity,
    testRightIdentity,
    testIdentityIdempotent,
    testMapIdentity,
    testMapFusion,
    testMapLength,
    testMapMaybeIdentity,
    testAppendNilRight,
    testAppendLength,
    testReverseSingleton,
    testEmptyTraceUseCount,
    testFilterLengthBound
  ]
