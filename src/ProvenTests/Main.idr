-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Main

import ProvenTests.Types
import ProvenTests.Zigzag
import ProvenTests.Coverage
import ProvenTests.Runners
import ProvenTests.Report
import System
import System.File
import Data.List

-- =============================================================================
-- MAIN ENTRY POINT
-- =============================================================================
-- Thin driver over the library. Runs the comprehensive suite, prints the human
-- report and the derived coverage map, and — with `--report <path>` — also
-- writes the machine-readable JSON run report consumed by estate tooling
-- (panic-attack aggregate; see docs/INTEROP-PANIC-ATTACK.adoc).
--
-- NOTE (2026-08-07): this comment used to describe printing that did not
-- happen. `main` called the silent runner, so the executable produced NO output
-- at all without `--report`, and the coverage map was computed and discarded on
-- every run. Printing is now real; `--quiet` suppresses it for scripted use.

--/ Extract a `--report <path>` argument, if present.
reportPath : List String -> Maybe String
reportPath ("--report" :: p :: _) = Just p
reportPath (_ :: rest)            = reportPath rest
reportPath []                     = Nothing

--/ Suppress the human report (the JSON report, if requested, is unaffected).
quiet : List String -> Bool
quiet args = elem "--quiet" args

main : IO ()
main = do
  args <- getArgs
  (ok, entries, covered) <- runComprehensiveSuiteData
  if quiet args then pure () else printRunReport entries covered
  case reportPath args of
    Nothing => pure ()
    Just path => do
      let json = runReportJSON entries
                   (coveredCatAspect covered, catAspectTotal, length covered)
      Right () <- writeFile path json
        | Left err => do putStrLn ("report: could not write " ++ path
                                    ++ ": " ++ show err)
                         exitFailure
      putStrLn ("report: wrote " ++ path)
  if ok then pure () else exitFailure
