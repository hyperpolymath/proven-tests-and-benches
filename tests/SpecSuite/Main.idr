-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module SpecSuite.Main

import ProvenTests.Types
import ProvenTests.Framework
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

allSuiteTests : List ProvisionallyProvenTest
allSuiteTests =
     allIdentityTests
  ++ allProjectionTests
  ++ allTraversalTests
  ++ allTransferTests
  ++ allBasicsTests
  ++ allAdvancedTests

suite : TestSuite
suite = MkTestSuite "Spec suites (HigherOrder + SetTheory)" (map toRunnable allSuiteTests)

isPass : TestResult -> Bool
isPass Passed = True
isPass _ = False

printOutcome : (TestMetadata, TestResult) -> IO ()
printOutcome (meta, result) =
  putStrLn $ "  [" ++ show (statusOf meta.provenance) ++ "] "
          ++ meta.test_id.test_name ++ ": " ++ show result

main : IO ()
main = do
  putStrLn "=== proven-spec-suite: HigherOrder + SetTheory ==="
  results <- runSuite suite
  traverse_ printOutcome results
  let passed = length (filter (isPass . snd) results)
  putStrLn $ "=== " ++ show passed ++ "/" ++ show (length results) ++ " passed ==="
  if passed == length results
     then putStrLn "SUITE: PASS"
     else do putStrLn "SUITE: FAIL"
             exitFailure
