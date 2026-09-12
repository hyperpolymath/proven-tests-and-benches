-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module SpecSuite.Main

import ProvenTests.Types
import ProvenTests.Framework
import ProvenLawsTests.LawsTests
import AffineScriptTests.AffinityTests
import AffineScriptTests.BorrowTests
import HigherOrderTests.IdentityTests
import HigherOrderTests.ProjectionTests
import HigherOrderTests.TraversalTests
import HigherOrderTests.TransferTests
import SetTheoryTests.BasicsTests
import SetTheoryTests.AdvancedTests
import System

-- =============================================================================
-- SPEC-RECONCILIATION SUITE ENTRY POINT
-- =============================================================================
-- Aggregates the HigherOrder and SetTheory suites named in the Proven Tests
-- spec (standards .github/ISSUES/cicd-optimization/004-tests-benches-standards.md
-- §3.1) and exits non-zero if any test fails, so this executable can gate CI.
--
-- EchoTypes is absent on purpose: see src/ProvenTests/EchoTypes/README.adoc.
-- There is no formal definition of an echo type anywhere in the estate to
-- encode, so writing one here would be inventing it.

-- =============================================================================
-- B.2 NEGATIVE WITNESS (TEST-DOCTRINE.adoc §2; plan Phase B verification)
-- =============================================================================
-- "Attempt to construct a test without a fixture pair; it must not compile.
-- A type error, not a lint warning. That IS the verification." The block below
-- is the pre-B.2 shape of MkTestMetadata — six fields, no FixtureObligation —
-- and `failing` asserts the type checker rejects it, so this witness itself
-- fails to build if the obligation is ever weakened back out of TestMetadata.
failing
  noFixturePosition : TestMetadata
  noFixturePosition =
    MkTestMetadata (MkTestId "SpecSuite" "no-fixture-position" 0)
      "constructed without stating a fixture position" Nothing Nothing Nothing
      PUnproven

allSuiteTests : List ProvisionallyProvenTest
allSuiteTests =
     allAffinityTests
  ++ allBorrowTests
  ++ allIdentityTests
  ++ allProjectionTests
  ++ allTraversalTests
  ++ allTransferTests
  ++ allBasicsTests
  ++ allAdvancedTests

suite : TestSuite
suite = MkTestSuite "Spec suites (Proven + AffineScript + HigherOrder + SetTheory)"
          (map toRunnable allProvenLawsTests ++ map toRunnable allSuiteTests)

isPass : TestResult -> Bool
isPass Passed = True
isPass _ = False

printOutcome : (TestMetadata, TestResult) -> IO ()
printOutcome (meta, result) =
  putStrLn $ "  [" ++ show (statusOf meta.provenance) ++ "] "
          ++ meta.test_id.test_name ++ ": " ++ show result

main : IO ()
main = do
  putStrLn "=== proven-spec-suite: Proven + AffineScript + HigherOrder + SetTheory ==="
  results <- runSuite suite
  traverse_ printOutcome results
  let passed = length (filter (isPass . snd) results)
  putStrLn $ "=== " ++ show passed ++ "/" ++ show (length results) ++ " passed ==="
  if passed == length results
     then putStrLn "SUITE: PASS"
     else do putStrLn "SUITE: FAIL"
             exitFailure
