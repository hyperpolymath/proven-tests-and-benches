-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Zigzag

import ProvenTests.Types
import ProvenTests.Taxonomy
import Data.List

-- =============================================================================
-- THE ZIGZAG REGIMEN
-- =============================================================================
-- An organising principle for Proven-Tests in the age of human-and-things
-- co-creation. Every claim about co-created software lives at a coordinate in a
-- lattice (co-phase x actor x category x aspect) and carries a provenance tier.
-- Testing is the disciplined *zigzag* traversal of that lattice, so that no cell
-- is silently left empty. See docs/ZIGZAG-REGIMEN.adoc for the full rationale.

-- The co-creation lifecycle: the five phases humans and things move through
-- together.
public export
data CoPhase : Type where
  CoConception     : CoPhase
  CoDesign         : CoPhase
  CoDevelopment    : CoPhase
  CoImplementation : CoPhase
  CoEvaluation     : CoPhase

export
Show CoPhase where
  show CoConception     = "co-conception"
  show CoDesign         = "co-design"
  show CoDevelopment    = "co-development"
  show CoImplementation = "co-implementation"
  show CoEvaluation     = "co-evaluation"

-- The actor a claim is about: a human, a thing (machine / agent / device), or
-- the collective (the human+thing pair acting jointly -- the "co-").
public export
data Actor : Type where
  Human      : Actor
  Thing      : Actor
  Collective : Actor

export
Show Actor where
  show Human      = "human"
  show Thing      = "thing"
  show Collective = "collective"

public export
allCoPhases : List CoPhase
allCoPhases = [CoConception, CoDesign, CoDevelopment, CoImplementation, CoEvaluation]

public export
allActors : List Actor
allActors = [Human, Thing, Collective]

-- A coordinate in the testing lattice: what is being claimed, by/about whom, in
-- which category, about which aspect.
public export
record ZigzagCoord where
  constructor MkCoord
  phase    : CoPhase
  actor    : Actor
  category : TestCategory
  aspect   : TestAspect

export
Show ZigzagCoord where
  show (MkCoord ph ac cat asp) =
    "(" ++ show ph ++ ", " ++ show ac ++ ", " ++ show cat ++ ", " ++ show asp ++ ")"

-- =============================================================================
-- THE ZIGZAG TRAVERSAL
-- =============================================================================
-- A boustrophedon ("as the ox ploughs") walk of the category x aspect plane:
-- each category is a row; aspects run left-to-right on one row and right-to-left
-- on the next. Adjacent visited cells therefore differ in exactly one axis,
-- which minimises context switching while still visiting every cell once.

zigzagRows : Bool -> List TestCategory -> List TestAspect ->
             List (TestCategory, TestAspect)
zigzagRows _   []        _       = []
zigzagRows ltr (c :: cs) aspects =
  let row = if ltr then aspects else reverse aspects in
  map (\a => (c, a)) row ++ zigzagRows (not ltr) cs aspects

--/ Zigzag traversal of a category x aspect plane
public export
zigzag : List TestCategory -> List TestAspect -> List (TestCategory, TestAspect)
zigzag cats aspects = zigzagRows True cats aspects

--/ Every category x aspect cell, in zigzag order
public export
allZigzagCells : List (TestCategory, TestAspect)
allZigzagCells = zigzag allTestCategories allTestAspects

--/ The full lattice of coordinates (co-phase x actor x category x aspect)
public export
latticeCoords : List ZigzagCoord
latticeCoords =
  concatMap (\ph =>
    concatMap (\ac =>
      map (\cell => MkCoord ph ac (fst cell) (snd cell)) allZigzagCells)
      allActors)
    allCoPhases

--/ Size of the full lattice
public export
latticeSize : Nat
latticeSize = length latticeCoords

-- =============================================================================
-- PROVENANCE FLOOR
-- =============================================================================

--/ The minimum provenance a coordinate's category is expected to reach.
--/ Ties the regimen to the evidence tiers (see ProvenTests.Classification).
public export
coordProvenanceFloor : ZigzagCoord -> ProvenStatus
coordProvenanceFloor c = categoryToTypicalProvenance (category c)

--/ One-line summary of the lattice dimensions
public export
zigzagSummary : String
zigzagSummary =
  "Zigzag lattice: "
  ++ show (length allCoPhases)       ++ " phases x "
  ++ show (length allActors)         ++ " actors x "
  ++ show (length allTestCategories) ++ " categories x "
  ++ show (length allTestAspects)    ++ " aspects = "
  ++ show latticeSize ++ " coordinates"
