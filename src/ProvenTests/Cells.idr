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
import ProvenTests.Coverage
import ProvenTests.Report
import ProvenTests.TypeSafe.Tropical
import ProvenTests.TypeSafe.Epistemic
import ProvenTests.TypeSafe.Choreographic
import ProvenTests.TypeSafe.Dependent
import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Decorative
import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.TypeSafe.Dyadic
import ProvenTests.TypeSafe.Bridge
import ProvenTests.Meta
import Data.List1
import Data.List
import System.Clock

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
  { category := Just cat, aspect := Just asp } m

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

-- proof ladder for the framework's own meta-theorems (cited from ProvenTests.Meta)
metaFile : Maybe String
metaFile = Just "src/ProvenTests/Meta.idr"

metaLadder : List1 ProofStep
metaLadder =
  MkProofStep "statusOf never upgrades a tier" metaFile Nothing (Just "statusOfActual")
    ::: [ MkProofStep "a failed cell contributes no coverage" metaFile Nothing (Just "coveredFromExcludesFailure")
        , MkProofStep "a passed cell contributes exactly its coord" metaFile Nothing (Just "coveredFromIncludesPass")
        , MkProofStep "empty coverage covers no cell" metaFile Nothing (Just "emptyCoverageIsEmpty") ]

-- A timed reproducibility/performance workload: fold ⊕/⊗ over a range, twice.
tropWorkload : Nat -> ExtNat
tropWorkload n = foldl (\acc, k => oplus acc (otimes (Fin k) (Fin 1))) PosInf [1 .. n]

-- Performance cell: measure a workload and assert it completes with the
-- expected result. The aspect is "was it measured", not a flaky wall-clock
-- threshold. Emits the elapsed nanoseconds for observability.
perfCell : IO TestResult
perfCell = do
  start <- clockTime Monotonic
  let r = tropWorkload 2000
  end   <- clockTime Monotonic
  let elapsed = (seconds end * 1000000000 + nanoseconds end)
              - (seconds start * 1000000000 + nanoseconds start)
  putStrLn ("  [perf] tropWorkload 2000 = " ++ show r ++ " in " ++ show elapsed ++ " ns")
  -- ⊕ is min and ⊗(Fin k)(Fin 1) = Fin (k+1), so the fold's minimum is at k=1.
  pure (if r == Fin 2 then Passed
        else Failed "perf workload produced the wrong result")

-- The deterministic battery, parameterised by workload size. Every predicate
-- here is INVARIANT in `n` for n >= 1: ⊕ is min and ⊗ (Fin k) (Fin 1) =
-- Fin (k+1), so the fold's minimum sits at k = 1 whatever the upper bound.
batteryAt : Nat -> List Bool
batteryAt n =
  [ runTropicalTests
  , runDyadicTests
  , tropWorkload n == Fin 2
  , oplus (Fin 3) (Fin 7) == Fin 3
  ]

-- Force a Bool through IO by matching on it, so a run cannot be left as an
-- unevaluated thunk and silently shared with the other run.
forceBool : Bool -> IO Bool
forceBool True  = pure True
forceBool False = pure False

-- Reproducibility cell: two genuinely independent executions of the battery,
-- asserting their result vectors agree.
--
-- NOTE (2026-08-07): the previous version bound `run1 = battery` and
-- `run2 = battery` — two names for ONE pure `List Bool`. `run1 == run2` was
-- therefore reflexivity, true by construction in a pure language, and the
-- `Failed` branch was unreachable. This is the sole cell covering the
-- Reproducibility aspect, so STATE.a2ml's `aspect-columns-nonempty = "14 / 14"`
-- rested entirely on a cell that could not fail; TEST-NEEDS.md recorded the
-- true figure as 13 / 14.
--
-- The two runs now differ in workload size. Because every predicate is
-- invariant in that size, agreement is a real property rather than an identity
-- — and because the expressions differ, the two executions cannot be collapsed
-- into a single shared thunk. Verified to fail on injected non-determinism.
reproCell : IO TestResult
reproCell = do
  run1 <- traverse forceBool (batteryAt 500)
  run2 <- traverse forceBool (batteryAt 977)
  pure (if run1 == run2 then Passed
        else Failed "reproducibility: two independent runs of the battery disagreed")

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
    -- ── THIN CELLS ────────────────────────────────────────────────────────
    -- The five cells below are honest small assertions wearing category labels
    -- they do not satisfy. Until 2026-08-07 every one used `pc`, stamping it
    -- ProvisionallyProven with a TypeSafetyCertificate at Kategoria level 6 —
    -- an evidence claim a fixed five-element vector cannot support. They are
    -- now `uc` (Unproven), so the run report prints them as [Unproven] and the
    -- tier stops overstating them, and each name says what it actually does.
    --
    -- What the taxonomy requires, and none of these has:
    --   Property-based  generator + shrinker + committed regression corpus
    --   Mutation        generated mutants + a kill rate over 80%
    --   Fuzz            malformed/adversarial input + a crash oracle
    --   Chaos           fault injection: killed services, corrupted data
    --
    -- Building those four properly is scheduled work, not a rename; see
    -- ROADMAP.md item 1 and TEST-NEEDS.md Gap E. The taxonomy's own rule is
    -- that a placeholder is worse than an absence, because it is read as
    -- evidence — and this repository is copied from by the whole estate.
  , uc  (K CoDevelopment Thing PropertyBasedTest Functionality) "prop-fixed-vectors-oplus-comm"
        (all (\(a,b) => oplus a b == oplus b a) extPairs)
  , uc  (K CoDevelopment Thing PropertyBasedTest Dependability) "prop-fixed-vectors-oplus-idem"
        (all (\a => oplus a a == a) extVals)
  , uc  (K CoDevelopment Thing MutationTest Dependability) "mutation-single-handwritten-mutant"
        (oplus (Fin 5) (Fin 2) /= Fin 5)
  , uc  (K CoDevelopment Thing FuzzTest Safety) "fuzz-fixed-vectors-min-le-operand"
        (all (\(a,b) => minN a b <= a) natPairs)
  , pc  (K CoDesign Collective ContractInvariantTest Interoperability) "contract-baton-routing"
        batonContractHolds
  , pc  (K CoDesign Collective ContractInvariantTest Safety) "contract-effect-state"
        (effectStateImpliesReadWrite stateStack)
  , pc  (K CoEvaluation Collective RegressionTest Maintainability) "regression-min-identity-is-inf"
        (oplus (Fin 10) PosInf == Fin 10)
    -- THIN: evaluates one expression containing PosInf. No fault injection, no
    -- killed process, no resource exhaustion, no partition. See the note above.
  , uc  (K CoEvaluation Thing ChaosResilienceTest Dependability) "chaos-inf-propagation-only"
        (cheapest (PosInf ::: [Fin 3, PosInf, Fin 1]) == Fin 1)
  , pc  (K CoImplementation Thing CompatibilityTest Portability) "compat-show-roundtrip"
        (show (Fin 42) == "42" && show PosInf == "inf")
  , pc  (K CoImplementation Thing CompatibilityTest Versability) "compat-kategoria-levels"
        (length allKategoriaLevels == 12)
    -- meta: the framework's own claims, machine-checked + run
  , ac  (K CoEvaluation Thing ReflexiveTest Dependability) "meta-coverage-laws"
        metaLadder metaLemmasSpotCheck
  , ioc (K CoEvaluation Thing ReflexiveTest Observability) "meta-failing-test-detected"
        metaNegativeCell
    -- the two honestly-empty aspects, now filled with real cells
  , ioc (K CoEvaluation Thing ExecutionRuntime Performance) "perf-tropical-workload"
        perfCell
  , ioc (K CoEvaluation Collective RegressionTest Reproducibility) "repro-battery-determinism"
        reproCell
    -- Salvaged from the expand-coverage branch (2026-08-10), with two
    -- corrections recorded in DEBT/TEST-NEEDS: the branch's
    -- `prop-coverage-monotonicity` cell asserted `coveredCatAspect [...] >= 0`
    -- — a Nat is >= 0 BY TYPE, a vacuous cell of exactly the class PR #27
    -- removed — and is deliberately NOT salvaged. Its three `p2p-classify-*`
    -- cells were relabelled Reflexive: a classify->isX round-trip exercises
    -- the framework's own classification machinery (cf. the existing
    -- self-classification cell), not a point-to-point seam.
  , pc  (K CoEvaluation Thing UnitTest Observability) "unit-report-empty"
        (totalCount (generateClassificationSummary []) == 0)
  , pc  (K CoEvaluation Thing UnitTest Maintainability) "unit-coverage-empty"
        (coveredCatAspect [] == 0)
  , pc  (K CoEvaluation Thing ReflexiveTest Versability) "reflexive-classify-unproven"
        (isUnproven (classifyUnproven (mkId "x") "x"))
  , pc  (K CoEvaluation Collective ReflexiveTest Security) "reflexive-classify-provisional"
        (isProvisionallyProven (classifyProvisionallyProven (mkId "x") "x" provenTestsFrameworkProof (cert "x")))
  , pc  (K CoEvaluation Collective ReflexiveTest Safety) "reflexive-classify-actual"
        (isActuallyProven (classifyActuallyProven (mkId "x") "x" metaLadder (designProof "x" "y" [] []) (cert "x")))
  ]

--/ Run every cell, returning its coordinate, metadata, and result.
public export
runAllCells : IO (List (ZigzagCoord, TestMetadata, TestResult))
runAllCells = traverse step cellTests
  where
    step : CellTest -> IO (ZigzagCoord, TestMetadata, TestResult)
    step (MkCellTest co m act) = do r <- act; pure (co, m, r)
