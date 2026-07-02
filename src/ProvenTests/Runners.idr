-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Runners

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Zigzag
import ProvenTests.Coverage
import ProvenTests.Cells

-- NOTE: the per-category runners that used to live here (runTropicalCategoryTests
-- et al., runTypeSafeTests, runAllTests, runTropicalLawTests, runE2ECategoryTests)
-- were superseded by the typed lattice cells in ProvenTests.Cells — every one of
-- their checks now runs as a CellTest with a real ZigzagCoord, so coverage is
-- derived rather than asserted. They have been removed.

-- =============================================================================
-- SELF-CLASSIFICATION TEST (Reflexive)
-- =============================================================================

--/ Test that the framework correctly classifies itself
public export
runSelfClassification : IO (TestMetadata, TestResult)
runSelfClassification =
  let expected = ProvisionallyProven
      actual   = getProvenStatus provenTestsMetadata in
  if actual == expected
    then pure (provenTestsMetadata, Passed)
    else pure (provenTestsMetadata, Failed "Self-classification mismatch")

-- =============================================================================
-- COMPREHENSIVE TEST SUITE
-- =============================================================================

--/ Pretty-print a single result line (with its lattice coordinate, if recorded)
printResult : (TestMetadata, TestResult) -> IO ()
printResult (meta, result) =
  let coord = case (category meta, aspect meta) of
                (Just c, Just a) => " {" ++ c ++ "/" ++ a ++ "}"
                _                => ""
  in putStrLn ("[" ++ show (getProvenStatus meta) ++ "] "
            ++ show (test_id meta) ++ coord ++ ": " ++ show result)

--/ Whether a result counts as passed
isPassed : (TestMetadata, TestResult) -> Bool
isPassed (_, Passed) = True
isPassed _           = False

--/ One-line pass/fail summary over a list of results
summaryLine : List (TestMetadata, TestResult) -> String
summaryLine rs =
  let passed = length (filter isPassed rs) in
  let count = length rs in
  let verdict = if passed == count then "all passed" else "some failed" in
  "Passed: " ++ show passed ++ "/" ++ show count ++ "  (" ++ verdict ++ ")"

isPassR : TestResult -> Bool
isPassR Passed = True
isPassR _      = False

--/ Run the comprehensive suite with a summary; returns True iff all passed.
--/ Includes the framework's self-classification check (Reflexive) alongside
--/ the lattice cells. Coverage is derived only from cells that ran and passed.
public export
runComprehensiveSuite : IO Bool
runComprehensiveSuite = do
  putStrLn "=== Proven-Tests Framework ==="
  putStrLn zigzagSummary
  putStrLn ""
  self <- runSelfClassification
  cellResults <- runAllCells
  let entries = self :: map (\(_, m, r) => (m, r)) cellResults
  traverse_ printResult entries
  putStrLn ""
  putStrLn "=== Test Summary ==="
  putStrLn (summaryLine entries)
  putStrLn ""
  let covered = map (\(co, _, _) => co)
                    (filter (\(_, _, r) => isPassR r) cellResults)
  putStr (coverageReportFrom covered)
  pure (all isPassed entries)
