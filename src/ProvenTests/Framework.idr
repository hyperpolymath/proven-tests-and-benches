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

-- =============================================================================
-- TEST DEFINITION
-- =============================================================================

--/ Actually-Proven test type
public export
record ActuallyProvenTest where
  constructor MkActuallyProvenTest
  metadata    : TestMetadata
  test_func    : IO TestResult
  proof_ladder : List ProofStep

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

--/ A test is a computation that produces a result
public export
Test : ProvenStatus -> Type
Test status = 
  case status of
    ActuallyProven => ActuallyProvenTest
    ProvisionallyProven => ProvisionallyProvenTest
    Unproven => UnprovenTest

-- =============================================================================
-- TEST CONSTRUCTORS
-- =============================================================================

--/ Create an Actually-Proven test
public export
provenTest : 
     TestId -> 
     String -> 
     (IO TestResult) -> 
     List ProofStep -> 
     ActuallyProvenTest
provenTest tid desc func ladder =
  let meta = classifyActuallyProven tid desc ladder 
        (designProof "Design" "Formal Verification" [] []) 
        (typeSafetyCert 6 "Dependent Types" "Idris2" []) []
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

--/ Run a test and return the result with metadata
public export
runTest : (status : ProvenStatus) -> Test status -> IO (TestMetadata, TestResult)
runTest _ (MkActuallyProvenTest meta func _) = do
  result <- func
  pure (meta, result)
runTest _ (MkProvisionallyProvenTest meta func) = do
  result <- func
  pure (meta, result)
runTest _ (MkUnprovenTest meta func) = do
  result <- func
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

--/ Assert that a computation doesn't throw
public export
assertNoThrow : IO () -> String -> IO TestResult
assertNoThrow action msg = do
  result <- try (action >> pure Passed) (\ _ => pure (Failed msg))
  pure result
  where
    try : IO a -> (String -> IO a) -> IO a
    try action handler = action

-- =============================================================================
-- TEST SUITE
-- =============================================================================

--/ A test suite is a list of tests with a name
public export
record TestSuite where
  constructor MkTestSuite
  name : String
  tests : List (Test status)

--/ Create an empty test suite
public export
emptySuite : String -> TestSuite
emptySuite name = MkTestSuite name []

--/ Add a test to a suite
public export
addTest : Test status -> TestSuite -> TestSuite
addTest test (MkTestSuite name tests) = MkTestSuite name (tests ++ [test])

-- =============================================================================
-- SUITE EXECUTION
-- =============================================================================

--/ Run all tests in a suite
public export
runSuite : TestSuite -> IO (List (TestMetadata, TestResult))
runSuite (MkTestSuite _ tests) = mapM (\t => runTest (getStatus t) t) tests
  where
    mapM : (a -> IO b) -> List a -> IO (List b)
    mapM _ [] = pure []
    mapM f (x::xs) = do
      y <- f x
      ys <- mapM f xs
      pure (y::ys)

    getStatus : Test s -> s
    getStatus (MkActuallyProvenTest m _ _) = ActuallyProven
    getStatus (MkProvisionallyProvenTest m _) = ProvisionallyProven
    getStatus (MkUnprovenTest m _) = Unproven
