-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Framework

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Taxonomy
import Data.List1

-- =============================================================================
-- TEST DEFINITION
-- =============================================================================

--/ Actually-Proven test type
public export
record ActuallyProvenTest where
  constructor MkActuallyProvenTest
  metadata    : TestMetadata
  test_func    : IO TestResult
  proof_ladder : List1 ProofStep

--/ Provisionally-Proven test type
public export
record ProvisionallyProvenTest where
  constructor MkProvisionallyProvenTest
  metadata    : TestMetadata
  test_func    : IO TestResult

--/ Unproven test type
public export
record UnprovenTest where
  constructor MkUnprovenTest
  metadata    : TestMetadata
  test_func    : IO TestResult

--/ Anything runnable yields its metadata and a result-producing action.
--/ This replaces the previous computed-type machinery with a uniform interface
--/ so suites can hold tests of mixed provenance.
public export
interface Runnable t where
  toRunnable : t -> (TestMetadata, IO TestResult)

public export
Runnable ActuallyProvenTest where
  toRunnable (MkActuallyProvenTest m f _) = (m, f)

public export
Runnable ProvisionallyProvenTest where
  toRunnable (MkProvisionallyProvenTest m f) = (m, f)

public export
Runnable UnprovenTest where
  toRunnable (MkUnprovenTest m f) = (m, f)

-- =============================================================================
-- TEST CONSTRUCTORS
-- =============================================================================

--/ Create an Actually-Proven test
public export
provenTest :
     TestId ->
     String ->
     (IO TestResult) ->
     List1 ProofStep ->
     ActuallyProvenTest
provenTest tid desc func ladder =
  let meta = classifyActuallyProven tid desc ladder
        (designProof "Design" "Formal Verification" [] [])
        (typeSafetyCert 6 "Dependent Types" "Idris2" [])
  in MkActuallyProvenTest meta func ladder

--/ Create a Provisionally-Proven test
public export
provisionalTest : 
     TestId -> 
     String -> 
     (IO TestResult) -> 
     ProvisionallyProvenTest
provisionalTest tid desc func =
  let meta = classifyProvisionallyProven tid desc 
        (frameworkProof "Proven-Tests" 
          (typeSafetyCert 6 "Dependent Types" "Idris2" []) 
          (typeSafetyCert 6 "Dependent Types" "Idris2" [])
          "") 
        (typeSafetyCert 6 "Dependent Types" "Idris2" [])
  in MkProvisionallyProvenTest meta func

--/ Create an Unproven test
public export
unprovenTest : 
     TestId -> 
     String -> 
     (IO TestResult) -> 
     UnprovenTest
unprovenTest tid desc func =
  let meta = classifyUnproven tid desc
  in MkUnprovenTest meta func

-- =============================================================================
-- TEST EXECUTION
-- =============================================================================

--/ Run a test and return its metadata alongside the result
public export
runTest : Runnable t => t -> IO (TestMetadata, TestResult)
runTest x =
  let (meta, action) = toRunnable x in
  do result <- action
     pure (meta, result)

-- =============================================================================
-- ASSERTIONS
-- =============================================================================

--/ Assert that a boolean is true
public export
assertTrue : Bool -> String -> IO TestResult
assertTrue True _ = pure Passed
assertTrue False msg = pure (Failed msg)

--/ Assert that two values are equal
public export
assertEq : Eq a => a -> a -> String -> IO TestResult
assertEq x y msg = if x == y then pure Passed else pure (Failed msg)

-- NOTE: a previous `assertNoThrow` was removed: it claimed to catch exceptions
-- but its helper ignored the handler and caught nothing. Re-add only with a real
-- implementation (e.g. via Control.App or System exception handling).

-- =============================================================================
-- TEST SUITE
-- =============================================================================

--/ A test suite is a list of runnable tests (of any provenance) with a name
public export
record TestSuite where
  constructor MkTestSuite
  name : String
  tests : List (TestMetadata, IO TestResult)

--/ Create an empty test suite
public export
emptySuite : String -> TestSuite
emptySuite name = MkTestSuite name []

--/ Add a test to a suite
public export
addTest : Runnable t => t -> TestSuite -> TestSuite
addTest test (MkTestSuite name tests) = MkTestSuite name (tests ++ [toRunnable test])

-- =============================================================================
-- SUITE EXECUTION
-- =============================================================================

--/ Run all tests in a suite
public export
runSuite : TestSuite -> IO (List (TestMetadata, TestResult))
runSuite (MkTestSuite _ tests) = traverse runOne tests
  where
    runOne : (TestMetadata, IO TestResult) -> IO (TestMetadata, TestResult)
    runOne (meta, action) = do
      result <- action
      pure (meta, result)
