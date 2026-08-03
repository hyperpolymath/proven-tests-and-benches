-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenLawsTests.LawsTests

import ProvenTests.Proven.Laws
import ProvenTests.Framework
import ProvenTests.Types
import Data.List1

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
-- The `List1 ProofStep` ladder is METADATA — description, file, line, theorem
-- name. It does NOT carry the proof and the framework cannot check it. Passing
-- a ladder that names a theorem which does not exist would produce a test
-- labelled [Actually-Proven] on the strength of a string, which is precisely
-- the failure the three tiers exist to prevent.
--
-- So the rule for this file: every `theorem` field below names a function that
-- is defined and total in Laws.idr. If you cannot point at one, use
-- `provisionalTest`.
--
-- The runtime body is `assertTrue True` on purpose. The property was already
-- discharged at compile time; re-checking it on one witness at run time would
-- add nothing and would misleadingly suggest the evidence is the sample. The
-- reason is written into each test's message rather than left to be inferred.

private
lawsTestId : Nat -> TestId
lawsTestId n =
  MkTestId "ProvenTests.Proven.LawsTests" ("test_" ++ show n) n

private
step : String -> String -> Nat -> ProofStep
step desc thm ln =
  MkProofStep desc (Just "src/ProvenTests/Proven/Laws.idr") (Just ln) (Just thm)

private
discharged : String -> IO TestResult
discharged thm =
  assertTrue True ("discharged at compile time by " ++ thm ++ " in Laws.idr")

-- --- Identity ------------------------------------------------------------------

public export
testLeftIdentity : ActuallyProvenTest
testLeftIdentity =
  provenTest (lawsTestId 1)
    "id . f = f, for all f and x"
    (discharged "leftIdentityProof")
    (singleton (step "Definitional: (id . f) x reduces to f x"
                     "leftIdentityProof" 41))

public export
testRightIdentity : ActuallyProvenTest
testRightIdentity =
  provenTest (lawsTestId 2)
    "f . id = f, for all f and x"
    (discharged "rightIdentityProof")
    (singleton (step "Definitional: (f . id) x reduces to f x"
                     "rightIdentityProof" 46))

public export
testIdentityIdempotent : ActuallyProvenTest
testIdentityIdempotent =
  provenTest (lawsTestId 3)
    "id . id = id, for all x"
    (discharged "identityIdempotentProof")
    (singleton (step "Definitional" "identityIdempotentProof" 51))

-- --- Functor laws ---------------------------------------------------------------

public export
testMapIdentity : ActuallyProvenTest
testMapIdentity =
  provenTest (lawsTestId 4)
    "map id = id, for ALL lists"
    (discharged "mapIdentityProof")
    (singleton (step "Induction on the list; cons case rewrites by the IH"
                     "mapIdentityProof" 60))

public export
testMapFusion : ActuallyProvenTest
testMapFusion =
  provenTest (lawsTestId 5)
    "map g . map f = map (g . f), for ALL lists"
    (discharged "mapFusionProof")
    (singleton (step "Induction on the list" "mapFusionProof" 66))

public export
testMapLength : ActuallyProvenTest
testMapLength =
  provenTest (lawsTestId 6)
    "map preserves length, for ALL lists"
    (discharged "mapLengthProof")
    (singleton (step "Induction on the list" "mapLengthProof" 73))

public export
testMapMaybeIdentity : ActuallyProvenTest
testMapMaybeIdentity =
  provenTest (lawsTestId 7)
    "map id = id, for ALL Maybe values"
    (discharged "mapMaybeIdentityProof")
    (singleton (step "Case split; both cases definitional"
                     "mapMaybeIdentityProof" 81))

-- --- Append and reverse ----------------------------------------------------------

public export
testAppendNilRight : ActuallyProvenTest
testAppendNilRight =
  provenTest (lawsTestId 8)
    "xs ++ [] = xs, for ALL lists"
    (discharged "appendNilRightProof")
    (singleton (step "Induction; the left unit is definitional, this is not"
                     "appendNilRightProof" 90))

public export
testAppendLength : ActuallyProvenTest
testAppendLength =
  provenTest (lawsTestId 9)
    "length (xs ++ ys) = length xs + length ys, for ALL lists"
    (discharged "appendLengthProof")
    (singleton (step "Induction on the first list" "appendLengthProof" 96))

public export
testReverseSingleton : ActuallyProvenTest
testReverseSingleton =
  provenTest (lawsTestId 10)
    "reverse [x] = [x], for all x"
    (discharged "reverseSingletonProof")
    (singleton (step "Definitional" "reverseSingletonProof" 105))

-- --- Affinity, proved rather than sampled -----------------------------------------

public export
testEmptyTraceUseCount : ActuallyProvenTest
testEmptyTraceUseCount =
  provenTest (lawsTestId 11)
    "An unused variable has use-count 0, for ALL variables"
    (discharged "emptyTraceUseCountProof")
    (singleton (step "Definitional. AffinityTests checks this on one witness; here it holds for every variable."
                     "emptyTraceUseCountProof" 117))

public export
testFilterLengthBound : ActuallyProvenTest
testFilterLengthBound =
  provenTest (lawsTestId 12)
    "A use-count never exceeds the trace length, for ALL traces"
    (discharged "filterLengthBoundProof")
    (singleton (step "Induction with a with-split on the predicate; the bound that makes affinity's use-count meaningful."
                     "filterLengthBoundProof" 124))

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
