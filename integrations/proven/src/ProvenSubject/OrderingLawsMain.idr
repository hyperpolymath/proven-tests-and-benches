-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.OrderingLawsMain

import ProvenSubject.OrderingLawsTests
import ProvenTests.Framework
import ProvenTests.Types
import System

%default total

-- =============================================================================
-- proven-ordering-laws — run the Actually-Proven laws of proven's vector clocks
-- =============================================================================
-- Reaching this executable at all means the laws typechecked against proven at
-- integrations/proven/PROVEN_PIN; running it records each discharged rung.

||| The suite of proven ordering-law tests.
suite : TestSuite
suite = MkTestSuite "proven SafeOrdering laws (vector clocks)"
          (map toRunnable allOrderingLawsTests)

||| True when a test result is a pass.
isPass : TestResult -> Bool
isPass Passed = True
isPass _ = False

||| Print one test outcome with its provenance tier.
printOutcome : (TestMetadata, TestResult) -> IO ()
printOutcome (meta, result) =
  putStrLn $ "  [" ++ show (statusOf meta.provenance) ++ "] "
          ++ meta.test_id.test_name ++ ": " ++ show result

||| Run every law test; exit non-zero if any did not pass.
main : IO ()
main = do
  putStrLn "=== proven-ordering-laws: proven SafeOrdering at PROVEN_PIN ==="
  results <- runSuite suite
  traverse_ printOutcome results
  let passed = length (filter (isPass . snd) results)
  putStrLn $ "=== " ++ show passed ++ "/" ++ show (length results) ++ " passed ==="
  if passed == length results
     then putStrLn "SUITE: PASS"
     else do putStrLn "SUITE: FAIL"
             exitFailure
