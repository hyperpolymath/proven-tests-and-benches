-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.E2E

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import ProvenTests.Tropical
import ProvenTests.Baton
import ProvenTests.Framework
import Data.List

-- =============================================================================
-- FIRST POPULATED ZIGZAG CELL — a real End-to-End test
-- =============================================================================
-- The EndToEnd category was empty and the category/aspect axes were decorative
-- (always Nothing). This is the first cell of the lattice filled by a genuine
-- test: it occupies coordinate (CoImplementation, Collective, EndToEnd,
-- Dependability), records that coordinate in its metadata, and exposes it as a
-- Baton so the mesh can schedule/route it.

--/ The lattice coordinate this test covers.
public export
e2eCoord : ZigzagCoord
e2eCoord = MkCoord CoImplementation Collective EndToEnd Dependability

-- A small inner suite, run end-to-end through the framework's own runner.
e2eInnerSuite : TestSuite
e2eInnerSuite =
  addTest (MkUnprovenTest
            (classifyUnproven (MkTestId "ProvenTests.E2E.inner" "step-a" 0) "pipeline step A")
            (pure Passed))
    (addTest (MkUnprovenTest
            (classifyUnproven (MkTestId "ProvenTests.E2E.inner" "step-b" 0) "pipeline step B")
            (pure Passed))
      (emptySuite "e2e-inner"))

--/ Metadata for the E2E test, with its lattice coordinate actually recorded —
--/ the first test to populate the (previously always-Nothing) category/aspect.
public export
e2eClassification : TestMetadata
e2eClassification =
  let cert = typeSafetyCert 6 "Idris2" "ProvenTests.Framework" ["end-to-end pipeline"]
      base = classifyProvisionallyProven
               (MkTestId "ProvenTests.E2E" "frameworkPipeline" 0)
               "E2E: build a suite, run it through Framework.runSuite, verify the report"
               provenTestsFrameworkProof cert
  in { category := Just (show EndToEnd), aspect := Just (show Dependability) } base

--/ The Baton carrying this cell across the mesh (coordinate + provenance + cost).
public export
e2eBaton : BatonSpec
e2eBaton = MkBatonSpec e2eCoord (provenance e2eClassification) (Fin 1)

isPass : TestResult -> Bool
isPass Passed = True
isPass _      = False

--/ The end-to-end test: drive a suite through the framework's runner and assert
--/ the whole pipeline (build suite -> run -> collect results) reports all-pass.
public export
runE2ETest : IO TestResult
runE2ETest = do
  results <- runSuite e2eInnerSuite
  let n      = length results
  let passed = length (filter (isPass . snd) results)
  pure (if n > 0 && passed == n
          then Passed
          else Failed "E2E pipeline did not report all-pass")
