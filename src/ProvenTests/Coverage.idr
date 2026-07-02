-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Coverage

import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import Data.String
import Data.List

%default total

-- =============================================================================
-- ZIGZAG COVERAGE MAP (self-deriving)
-- =============================================================================
-- The map is computed from a list of covered coordinates that the runner derives
-- from tests that ACTUALLY RAN AND PASSED. Nothing here is a hand-written claim:
-- a `#` requires a real, executed, passing test at that typed `ZigzagCoord`.
-- Everything is keyed on the typed coordinate, not the stringly metadata fields,
-- so a gap cannot hide and a `#` cannot be faked.

--/ Is any covered coordinate at this (category, aspect) — projecting over phase/actor?
public export
cellCoveredBy : List ZigzagCoord -> TestCategory -> TestAspect -> Bool
cellCoveredBy cov c a = any (\z => category z == c && aspect z == a) cov

--/ Number of (category x aspect) cells with at least one covered coordinate.
public export
coveredCatAspect : List ZigzagCoord -> Nat
coveredCatAspect cov =
  foldl (\acc, c => acc + length (filter (cellCoveredBy cov c) allTestAspects)) 0 allTestCategories

--/ Total (category x aspect) cells (17 x 14 = 238).
public export
catAspectTotal : Nat
catAspectTotal = length allTestCategories * length allTestAspects

-- ── rendering ────────────────────────────────────────────────────────────────

cell : List ZigzagCoord -> TestCategory -> TestAspect -> String
cell cov c a = (if cellCoveredBy cov c a then "#" else ".") ++ "  "

aspectHeader : String
aspectHeader =
  padRight 18 ' ' "" ++ concat (map (\a => padRight 3 ' ' (substr 0 2 (show a))) allTestAspects)

renderRow : List ZigzagCoord -> TestCategory -> String
renderRow cov c = padRight 18 ' ' (show c) ++ concat (map (cell cov c) allTestAspects)

--/ The category x aspect grid (rows = categories, cols = aspects; # = covered).
public export
coverageGrid : List ZigzagCoord -> String
coverageGrid cov = unlines (aspectHeader :: map (renderRow cov) allTestCategories)

--/ Full coverage report, derived from the covered coordinates.
public export
coverageReportFrom : List ZigzagCoord -> String
coverageReportFrom cov0 =
  let cov = nub cov0 in
  "== Zigzag coverage map (derived from tests that ran and passed) ==\n"
  ++ "covered: " ++ show (coveredCatAspect cov) ++ " / " ++ show catAspectTotal
       ++ " category x aspect cells"
       ++ "   (full lattice " ++ show (length cov) ++ " / " ++ show latticeSize ++ ")\n"
  ++ "(columns = first 2 letters of each aspect; # = covered, . = empty)\n\n"
  ++ coverageGrid cov
  ++ "\ncovered cells:\n"
  ++ concat (map (\z => "  " ++ show z ++ "\n") cov)
