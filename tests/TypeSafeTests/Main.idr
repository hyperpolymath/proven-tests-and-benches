-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module TypeSafeTests.Main

import ProvenTests.Types
import ProvenTests.Framework
import TypeSafeTests.TropicalTests
import TypeSafeTests.EpistemicTests
import TypeSafeTests.ChoreographicTests
import TypeSafeTests.DependentTests
import TypeSafeTests.EffectsTests
import TypeSafeTests.DecorativeTests
import TypeSafeTests.CeremonialTests
import TypeSafeTests.DyadicTests
import TypeSafeTests.BridgeTests
import System

-- =============================================================================
-- TYPE-SAFE TEST SUITE ENTRY POINT
-- =============================================================================
-- Aggregates the nine per-category suites into one TestSuite and exits
-- non-zero if any test fails, so this executable can gate CI.

allSuiteTests : List ProvisionallyProvenTest
allSuiteTests =
     allTropicalTests
  ++ allEpistemicTests
  ++ allChoreographicTests
  ++ allDependentTests
  ++ allEffectsTests
  ++ allDecorativeTests
  ++ allCeremonialTests
  ++ allDyadicTests
  ++ allBridgeTests

suite : TestSuite
suite = MkTestSuite "TypeSafe category suites" (map toRunnable allSuiteTests)

isPass : TestResult -> Bool
isPass Passed = True
isPass _ = False

printOutcome : (TestMetadata, TestResult) -> IO ()
printOutcome (meta, result) =
  putStrLn $ "  [" ++ show (statusOf meta.provenance) ++ "] "
          ++ meta.test_id.test_name ++ ": " ++ show result

main : IO ()
main = do
  putStrLn "=== proven-tests-suite: TypeSafe category suites ==="
  results <- runSuite suite
  traverse_ printOutcome results
  let passed = length (filter (isPass . snd) results)
  putStrLn $ "=== " ++ show passed ++ "/" ++ show (length results) ++ " passed ==="
  if passed == length results
     then putStrLn "SUITE: PASS"
     else do putStrLn "SUITE: FAIL"
             exitFailure
