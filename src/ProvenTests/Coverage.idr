-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Coverage

import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import ProvenTests.E2E
import Data.String
import Data.List

%default total

-- =============================================================================
-- ZIGZAG COVERAGE MAP
-- =============================================================================
-- A typed, compiler-checked coverage map over the lattice. The registry below
-- is the set of cells that have a real test; everything is keyed on the typed
-- `ZigzagCoord` (CoPhase x Actor x TestCategory x TestAspect), not on the
-- stringly metadata fields, so a coverage gap cannot hide and cannot be faked.
--
-- Today exactly one cell is covered (ProvenTests.E2E). As tests are added, list
-- their coordinate here — the map then reflects reality by construction.

--/ The cells that currently have a real test.
public export
coveredCells : List ZigzagCoord
coveredCells = [ e2eCoord ]

--/ Is any registered test at this (category, aspect) — projecting over phase/actor?
public export
cellCovered : TestCategory -> TestAspect -> Bool
cellCovered c a = any (\z => category z == c && aspect z == a) coveredCells

--/ Number of (category x aspect) cells with at least one test.
public export
coveredCatAspect : Nat
coveredCatAspect =
  foldl (\acc, c => acc + length (filter (cellCovered c) allTestAspects)) 0 allTestCategories

--/ Total (category x aspect) cells (17 x 14 = 238).
public export
catAspectTotal : Nat
catAspectTotal = length allTestCategories * length allTestAspects

-- ── rendering ────────────────────────────────────────────────────────────────

cell : TestCategory -> TestAspect -> String
cell c a = (if cellCovered c a then "#" else ".") ++ "  "

aspectHeader : String
aspectHeader =
  padRight 18 ' ' "" ++ concat (map (\a => padRight 3 ' ' (substr 0 2 (show a))) allTestAspects)

renderRow : TestCategory -> String
renderRow c = padRight 18 ' ' (show c) ++ concat (map (cell c) allTestAspects)

--/ The category x aspect grid (rows = categories, cols = aspects; # = covered).
public export
coverageGrid : String
coverageGrid = unlines (aspectHeader :: map renderRow allTestCategories)

--/ Full coverage report: headline fraction, the grid, and the covered cells.
public export
coverageReport : String
coverageReport =
  "== Zigzag coverage map ==\n"
  ++ "covered: " ++ show coveredCatAspect ++ " / " ++ show catAspectTotal
       ++ " category x aspect cells"
       ++ "   (full lattice " ++ show (length coveredCells) ++ " / " ++ show latticeSize ++ ")\n"
  ++ "(columns = first 2 letters of each aspect; # = covered, . = empty)\n\n"
  ++ coverageGrid
  ++ "\ncovered cells:\n"
  ++ concat (map (\z => "  " ++ show z ++ "\n") coveredCells)
