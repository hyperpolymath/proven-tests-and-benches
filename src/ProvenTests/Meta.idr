-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Meta

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Framework
import ProvenTests.Zigzag
import ProvenTests.Coverage
import Data.List
import Data.List1

%default total

-- =============================================================================
-- META-TESTS: the framework tests its own claims
-- =============================================================================
-- Two kinds of evidence, matching the framework's own tiers:
--
--  * Total, machine-checked lemmas (compile = proof). These back the
--    Actually-Proven meta cell: the provenance projection and the
--    coverage-derivation rules hold for ALL inputs.
--  * Runtime negative tests: a deliberately failing test must be *reported*
--    as failing. A test framework that cannot fail is not testing anything.

-- ── Machine-checked lemmas ───────────────────────────────────────────────────

--/ statusOf maps each provenance constructor to its own tier — never upgrades.
export
statusOfUnproven : statusOf PUnproven = Unproven
statusOfUnproven = Refl

export
statusOfProvisional : (e : ProvisionalEvidence)
                   -> statusOf (PProvisionallyProven e) = ProvisionallyProven
statusOfProvisional _ = Refl

export
statusOfActual : (e : ActualEvidence)
              -> statusOf (PActuallyProven e) = ActuallyProven
statusOfActual _ = Refl

--/ A failed cell contributes NOTHING to derived coverage, for any coordinate,
--/ any metadata, any failure message. This is the "a # cannot be faked" claim,
--/ machine-checked.
export
coveredFromExcludesFailure : (co : ZigzagCoord) -> (m : TestMetadata)
                          -> (msg : String)
                          -> coveredFrom [(co, m, Failed msg)] = []
coveredFromExcludesFailure _ _ _ = Refl

--/ Errored and skipped cells are excluded too.
export
coveredFromExcludesError : (co : ZigzagCoord) -> (m : TestMetadata)
                        -> (msg : String)
                        -> coveredFrom [(co, m, Error msg)] = []
coveredFromExcludesError _ _ _ = Refl

export
coveredFromExcludesSkipped : (co : ZigzagCoord) -> (m : TestMetadata)
                          -> (msg : String)
                          -> coveredFrom [(co, m, Skipped msg)] = []
coveredFromExcludesSkipped _ _ _ = Refl

--/ A passed cell contributes exactly its own coordinate.
export
coveredFromIncludesPass : (co : ZigzagCoord) -> (m : TestMetadata)
                       -> coveredFrom [(co, m, Passed)] = [co]
coveredFromIncludesPass _ _ = Refl

--/ With no covered coordinates, no (category, aspect) cell is covered.
export
emptyCoverageIsEmpty : (c : TestCategory) -> (a : TestAspect)
                    -> cellCoveredBy [] c a = False
emptyCoverageIsEmpty _ _ = Refl

--/ Runtime spot-check mirroring the lemmas above (the lemmas hold for all
--/ inputs by compilation; this exercises them on concrete values at runtime
--/ so the meta cell also *runs* something).
export
metaLemmasSpotCheck : Bool
metaLemmasSpotCheck =
  let co = MkCoord CoEvaluation Thing ReflexiveTest Dependability
      m  = classifyUnproven (MkTestId "ProvenTests.Meta" "spot" 0) "spot" in
  statusOf PUnproven == Unproven
    && null (coveredFrom [(co, m, Failed "deliberate")])
    && coveredFrom [(co, m, Passed)] == [co]
    && not (cellCoveredBy [] ReflexiveTest Dependability)

-- ── Runtime negative tests ───────────────────────────────────────────────────

isFailureEntry : (TestMetadata, TestResult) -> Bool
isFailureEntry (_, Failed _) = True
isFailureEntry _             = False

isPassEntry : (TestMetadata, TestResult) -> Bool
isPassEntry (_, Passed) = True
isPassEntry _           = False

--/ Run an in-process suite containing one deliberately failing test and one
--/ passing test; the framework must report exactly one failure and one pass.
export
covering
metaFailingSuiteDetected : IO Bool
metaFailingSuiteDetected = do
  let good = unprovenTest (MkTestId "ProvenTests.Meta" "deliberate-pass" 0)
               "meta: this test passes" (pure Passed)
  let bad  = unprovenTest (MkTestId "ProvenTests.Meta" "deliberate-fail" 1)
               "meta: this test fails on purpose" (pure (Failed "deliberate failure"))
  results <- runSuite (addTest bad (addTest good (emptySuite "meta-negative-suite")))
  pure (length (filter isFailureEntry results) == 1
     && length (filter isPassEntry results) == 1)

--/ As a TestResult-producing action for use as a lattice cell.
export
covering
metaNegativeCell : IO TestResult
metaNegativeCell = do
  ok <- metaFailingSuiteDetected
  pure (if ok then Passed
        else Failed "framework failed to report a deliberately failing test")
