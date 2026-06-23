-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Runners

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import ProvenTests.Framework
import ProvenTests.TypeSafe.Tropical
import ProvenTests.TypeSafe.Epistemic
import ProvenTests.TypeSafe.Choreographic
import ProvenTests.TypeSafe.Dependent
import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Decorative
import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.TypeSafe.Dyadic
import ProvenTests.TypeSafe.Bridge

-- =============================================================================
-- SELF-CLASSIFICATION TEST
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
-- TYPE-SAFE CATEGORY RUNNERS
-- =============================================================================

public export
runTropicalCategoryTests : IO (List (TestMetadata, TestResult))
runTropicalCategoryTests =
  if runTropicalTests
    then pure [(tropicalClassification, Passed)]
    else pure [(tropicalClassification, Failed "Tropical tests failed")]

public export
runEpistemicCategoryTests : IO (List (TestMetadata, TestResult))
runEpistemicCategoryTests =
  if runEpistemicTests
    then pure [(epistemicClassification, Passed)]
    else pure [(epistemicClassification, Failed "Epistemic tests failed")]

public export
runChoreographicCategoryTests : IO (List (TestMetadata, TestResult))
runChoreographicCategoryTests =
  if runChoreographicTests
    then pure [(choreographicClassification, Passed)]
    else pure [(choreographicClassification, Failed "Choreographic tests failed")]

public export
runDependentCategoryTests : IO (List (TestMetadata, TestResult))
runDependentCategoryTests =
  if runDependentTests
    then pure [(dependentClassification, Passed)]
    else pure [(dependentClassification, Failed "Dependent tests failed")]

public export
runEffectsCategoryTests : IO (List (TestMetadata, TestResult))
runEffectsCategoryTests =
  if runEffectsTests
    then pure [(effectsClassification, Passed)]
    else pure [(effectsClassification, Failed "Effects tests failed")]

public export
runDecorativeCategoryTests : IO (List (TestMetadata, TestResult))
runDecorativeCategoryTests =
  if runDecorativeTests
    then pure [(decorativeClassification, Passed)]
    else pure [(decorativeClassification, Failed "Decorative tests failed")]

public export
runCeremonialCategoryTests : IO (List (TestMetadata, TestResult))
runCeremonialCategoryTests =
  if runCeremonialTests
    then pure [(ceremonialClassification, Passed)]
    else pure [(ceremonialClassification, Failed "Ceremonial tests failed")]

public export
runDyadicCategoryTests : IO (List (TestMetadata, TestResult))
runDyadicCategoryTests =
  if runDyadicTests
    then pure [(dyadicClassification, Passed)]
    else pure [(dyadicClassification, Failed "Dyadic tests failed")]

public export
runBridgeTests : IO (List (TestMetadata, TestResult))
runBridgeTests =
  if allBridgeTestsPass
    then pure [(bridgeClassification, Passed)]
    else pure [(bridgeClassification, Failed "Bridge tests failed")]

--/ Run all type-safe category tests
public export
runTypeSafeTests : IO (List (TestMetadata, TestResult))
runTypeSafeTests = do
  results <- sequence
    [ runTropicalCategoryTests
    , runEpistemicCategoryTests
    , runChoreographicCategoryTests
    , runDependentCategoryTests
    , runEffectsCategoryTests
    , runDecorativeCategoryTests
    , runCeremonialCategoryTests
    , runDyadicCategoryTests
    , runBridgeTests
    ]
  pure (concat results)

-- =============================================================================
-- COMPREHENSIVE TEST SUITE
-- =============================================================================

--/ Run all tests including the self-classification check
public export
runAllTests : IO (List (TestMetadata, TestResult))
runAllTests = do
  self     <- runSelfClassification
  typeSafe <- runTypeSafeTests
  pure (self :: typeSafe)

--/ Pretty-print a single result line
printResult : (TestMetadata, TestResult) -> IO ()
printResult (meta, result) = do
  putStrLn ("[" ++ show (getProvenStatus meta) ++ "] "
            ++ show (test_id meta) ++ ": " ++ show result)

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

--/ Run the comprehensive suite with a summary; returns True iff all passed
public export
runComprehensiveSuite : IO Bool
runComprehensiveSuite = do
  putStrLn "=== Proven-Tests Framework ==="
  putStrLn zigzagSummary
  putStrLn ""
  allResults <- runAllTests
  traverse_ printResult allResults
  putStrLn ""
  putStrLn "=== Test Summary ==="
  putStrLn (summaryLine allResults)
  pure (all isPassed allResults)
