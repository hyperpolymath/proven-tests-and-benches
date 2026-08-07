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
import Data.List

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
                (Just c, Just a) => " {" ++ show c ++ "/" ++ show a ++ "}"
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

-- NOTE (2026-08-07): there used to be two runners here — `runComprehensiveSuite`,
-- which printed the results and the derived 17x14 coverage map, and
-- `runComprehensiveSuiteData`, which returned the same data silently.
-- `ProvenTests.Main` called the silent one, and `runComprehensiveSuite` had ZERO
-- call sites anywhere in the repository. So `coverageGrid` — the artefact this
-- whole project is organised around, and the thing STATE.a2ml's coverage figures
-- describe — was computed on every run and thrown away, while `just test`
-- printed nothing at all and a reader had to take the numbers on trust.
--
-- Running and printing are now separated rather than duplicated: one runner
-- produces the data, one printer renders it. There is no second copy to fall
-- out of step with the first.

--/ Run the comprehensive suite and return everything a caller needs: whether all
--/ passed, the (metadata, result) entries, and the derived covered coordinates.
--/ Includes the framework's self-classification check (Reflexive) alongside the
--/ lattice cells. Coverage is derived only from cells that ran and passed.
public export
runComprehensiveSuiteData :
     IO (Bool, List (TestMetadata, TestResult), List ZigzagCoord)
runComprehensiveSuiteData = do
  self <- runSelfClassification
  cellResults <- runAllCells
  let entries = self :: map (\(_, m, r) => (m, r)) cellResults
  let covered = coveredFrom cellResults
  pure (all isPassed entries, entries, covered)

--/ Render the human-readable run report: header, one line per result, the
--/ pass/fail summary, and the derived category x aspect coverage map.
public export
printRunReport : List (TestMetadata, TestResult) -> List ZigzagCoord -> IO ()
printRunReport entries covered = do
  putStrLn "=== Proven-Tests Framework ==="
  putStrLn zigzagSummary
  putStrLn ""
  traverse_ printResult entries
  putStrLn ""
  putStrLn "=== Test Summary ==="
  putStrLn (summaryLine entries)
  putStrLn ""
  putStr (coverageReportFrom covered)
