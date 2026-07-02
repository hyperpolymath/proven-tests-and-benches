-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Cells

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import ProvenTests.Tropical
import ProvenTests.Baton
import ProvenTests.E2E
import ProvenTests.TypeSafe.Tropical
import ProvenTests.TypeSafe.Epistemic
import ProvenTests.TypeSafe.Choreographic
import ProvenTests.TypeSafe.Dependent
import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Decorative
import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.TypeSafe.Dyadic
import ProvenTests.TypeSafe.Bridge
import Data.List1
import Data.List

-- =============================================================================
-- LATTICE CELLS — self-deriving coverage
-- =============================================================================
-- Each CellTest binds a real test to a typed ZigzagCoord. Coverage is DERIVED
-- from running these: a cell counts as covered only if its test actually runs
-- and passes (see ProvenTests.Coverage + the runner). So a `#` on the map can
-- never be a hand-written claim — it requires a real, executed, passing test.

public export
record CellTest where
  constructor MkCellTest
  coord : ZigzagCoord
  meta  : TestMetadata
  run   : IO TestResult

toRes : Bool -> TestResult
toRes True  = Passed
toRes False = Failed "cell assertion was false"

-- Record the coordinate on the metadata so each result prints its {cat/aspect}.
withCoord : ZigzagCoord -> TestMetadata -> TestMetadata
withCoord (MkCoord _ _ cat asp) m =
  { category := Just (show cat), aspect := Just (show asp) } m

mkId : String -> TestId
mkId name = MkTestId "ProvenTests.Cells" name 0

cert : String -> TypeSafetyCertificate
cert name = typeSafetyCert 6 "Idris2" "ProvenTests.Cells" [name]

-- Provisionally-Proven cell from a pure boolean check.
pc : ZigzagCoord -> String -> Bool -> CellTest
pc co name b =
  MkCellTest co
    (withCoord co (classifyProvisionallyProven (mkId name) name provenTestsFrameworkProof (cert name)))
    (pure (toRes b))

-- Unproven (smoke-strength) cell from a pure boolean check.
uc : ZigzagCoord -> String -> Bool -> CellTest
uc co name b =
  MkCellTest co (withCoord co (classifyUnproven (mkId name) name)) (pure (toRes b))

-- Provisionally-Proven cell driven by an IO action (e.g. an end-to-end run).
ioc : ZigzagCoord -> String -> IO TestResult -> CellTest
ioc co name act =
  MkCellTest co
    (withCoord co (classifyProvisionallyProven (mkId name) name provenTestsFrameworkProof (cert name)))
    act

-- Actually-Proven cell: a machine-checked proof ladder + a runtime spot-check.
ac : ZigzagCoord -> String -> List1 ProofStep -> Bool -> CellTest
ac co name ladder b =
  MkCellTest co
    (withCoord co (classifyActuallyProven (mkId name) name ladder
       (designProof name "total, machine-checked Idris2 proofs" [] [])
       (cert name)))
    (pure (toRes b))

-- coordinate sugar
K : CoPhase -> Actor -> TestCategory -> TestAspect -> ZigzagCoord
K = MkCoord

-- proof ladder for the tropical laws (cited from ProvenTests.Tropical)
tropFile : Maybe String
tropFile = Just "src/ProvenTests/Tropical.idr"

tropLadder : List1 ProofStep
tropLadder =
  MkProofStep "min-plus (+) commutative" tropFile Nothing (Just "oplusComm")
    ::: [ MkProofStep "(+) associative" tropFile Nothing (Just "oplusAssoc")
        , MkProofStep "(+) idempotent"  tropFile Nothing (Just "oplusIdem")
        , MkProofStep "(*) commutative" tropFile Nothing (Just "otimesComm") ]

-- sample inputs for the property / fuzz cells
extPairs : List (ExtNat, ExtNat)
extPairs = [(Fin 0, Fin 3), (Fin 5, Fin 5), (Fin 2, PosInf), (PosInf, Fin 7), (Fin 9, Fin 1)]

extVals : List ExtNat
extVals = [Fin 0, Fin 3, Fin 7, PosInf]

natPairs : List (Nat, Nat)
natPairs = [(0,3),(5,5),(2,8),(9,1),(4,4)]

finPairs : List (ExtNat, ExtNat)
finPairs = [(Fin 1, Fin 4), (Fin 6, Fin 2), (Fin 3, Fin 3)]

-- =============================================================================
-- THE CELLS
-- =============================================================================

public export
cellTests : List CellTest
cellTests =
  [ -- existing tests, now bound to coordinates
    ioc (K CoImplementation Collective EndToEnd Dependability) "e2e-framework-pipeline" runE2ETest
  , ac  (K CoDevelopment Thing ProofRegressionTest Dependability) "tropical-semiring-laws" tropLadder tropicalLawsHold
  , pc  (K CoEvaluation Collective ReflexiveTest Maintainability) "self-classification"
        (getProvenStatus provenTestsMetadata == ProvisionallyProven)
    -- the nine type-safe category suites, one aspect each
  , pc  (K CoDevelopment Thing TypeSafeTest Functionality)    "typesafe-tropical"      runTropicalTests
  , pc  (K CoDesign Collective TypeSafeTest Privacy)          "typesafe-epistemic"     runEpistemicTests
  , pc  (K CoDesign Collective TypeSafeTest Interoperability) "typesafe-choreographic" runChoreographicTests
  , pc  (K CoDevelopment Thing TypeSafeTest Safety)          "typesafe-dependent"     runDependentTests
  , pc  (K CoDevelopment Thing TypeSafeTest Security)        "typesafe-effects"       runEffectsTests
  , pc  (K CoDevelopment Human TypeSafeTest Maintainability) "typesafe-decorative"    runDecorativeTests
  , pc  (K CoImplementation Collective TypeSafeTest Observability) "typesafe-ceremonial" runCeremonialTests
  , pc  (K CoDevelopment Thing TypeSafeTest Dependability)   "typesafe-dyadic"        runDyadicTests
  , pc  (K CoDesign Collective TypeSafeTest Versability)     "typesafe-bridge"        allBridgeTestsPass
    -- new cells filling the other categories
  , pc  (K CoDevelopment Thing UnitTest Functionality) "unit-tropical-ops"
        (oplus (Fin 2) (Fin 5) == Fin 2 && otimes (Fin 2) (Fin 5) == Fin 7)
  , pc  (K CoImplementation Collective PointToPoint Interoperability) "p2p-lte-oplus-agree"
        (all (\(a,b) => lteEN a b == (oplus a b == a)) finPairs)
  , pc  (K CoImplementation Thing BuildTest Maintainability) "build-taxonomy-cardinality"
        (length allTestCategories == 17 && length allTestAspects == 14)
  , uc  (K CoImplementation Thing BuildTest Accessibility) "build-aspect-labels-nonempty"
        (all (\a => show a /= "") allTestAspects)
  , pc  (K CoEvaluation Thing ExecutionRuntime Functionality) "exec-cheapest"
        (cheapest (Fin 9 ::: [Fin 4, Fin 1, Fin 7]) == Fin 1)
  , pc  (K CoEvaluation Collective LifecycleTest Observability) "lifecycle-ceremony-bounds"
        (ceremonyStartsProperly validCeremony && ceremonyEndsProperly validCeremony)
  , pc  (K CoEvaluation Collective LifecycleTest Functionality) "lifecycle-ceremony-order"
        (ceremonyHasRequiredOrder validCeremony)
  , uc  (K CoEvaluation Human SmokeTest Functionality) "smoke-oplus-identity"
        (oplus PosInf (Fin 1) == Fin 1)
  , uc  (K CoEvaluation Human SmokeTest Usability) "smoke-show-nonempty"
        (show EndToEnd /= "")
  , pc  (K CoDevelopment Thing PropertyBasedTest Functionality) "prop-oplus-comm"
        (all (\(a,b) => oplus a b == oplus b a) extPairs)
  , pc  (K CoDevelopment Thing PropertyBasedTest Dependability) "prop-oplus-idem"
        (all (\a => oplus a a == a) extVals)
  , pc  (K CoDevelopment Thing MutationTest Dependability) "mutation-min-distinguished"
        (oplus (Fin 5) (Fin 2) /= Fin 5)
  , pc  (K CoDevelopment Thing FuzzTest Safety) "fuzz-min-le-operand"
        (all (\(a,b) => minN a b <= a) natPairs)
  , pc  (K CoDesign Collective ContractInvariantTest Interoperability) "contract-baton-routing"
        batonContractHolds
  , pc  (K CoDesign Collective ContractInvariantTest Safety) "contract-effect-state"
        (effectStateImpliesReadWrite stateStack)
  , pc  (K CoEvaluation Collective RegressionTest Maintainability) "regression-min-identity-is-inf"
        (oplus (Fin 10) PosInf == Fin 10)
  , pc  (K CoEvaluation Thing ChaosResilienceTest Dependability) "chaos-cheapest-with-inf"
        (cheapest (PosInf ::: [Fin 3, PosInf, Fin 1]) == Fin 1)
  , pc  (K CoImplementation Thing CompatibilityTest Portability) "compat-show-roundtrip"
        (show (Fin 42) == "42" && show PosInf == "inf")
  , pc  (K CoImplementation Thing CompatibilityTest Versability) "compat-kategoria-levels"
        (length allKategoriaLevels == 12)
  ]

--/ Run every cell, returning its coordinate, metadata, and result.
public export
runAllCells : IO (List (ZigzagCoord, TestMetadata, TestResult))
runAllCells = traverse step cellTests
  where
    step : CellTest -> IO (ZigzagCoord, TestMetadata, TestResult)
    step (MkCellTest co m act) = do r <- act; pure (co, m, r)
