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
-- MAIN TEST RUNNER
-- =============================================================================

--/ Run all tests and print results
public export
main : IO ()
main = do
  putStrLn "=== Proven-Tests Framework ==="
  putStrLn ""
  
  -- Run self-classification test
  selfTest <- runSelfClassification
  printResult selfTest
  
  -- Run all type-safe tests
  typeSafeResults <- runTypeSafeTests
  mapM_ printResult typeSafeResults
  
  putStrLn ""
  putStrLn "=== Test Runner Complete ==="
  where
    printResult : (TestMetadata, TestResult) -> IO ()
    printResult (meta, result) = do
      putStrLn ("[" ++ show (getProvenStatus meta) ++ "] ")
      putStrLn (show (test_id meta) ++ ": " ++ show result)
      putStrLn ""

-- =============================================================================
-- SELF-CLASSIFICATION TEST
-- =============================================================================

--/ Test that the framework correctly classifies itself
public export
runSelfClassification : IO (TestMetadata, TestResult)
runSelfClassification = do
  -- The framework should be Provisionally-Proven
  let expected = ProvisionallyProven
  let actual = getProvenStatus provenTestsMetadata
  
  if actual == expected then
    pure (provenTestsMetadata, Passed)
  else
    pure (provenTestsMetadata, Failed "Self-classification mismatch")

-- =============================================================================
-- TYPE-SAFE TEST RUNNERS
-- =============================================================================

--/ Run all type-safe tests
public export
runTypeSafeTests : IO (List (TestMetadata, TestResult))
runTypeSafeTests = do
  results <- sequence [
    runTropicalCategoryTests,
    runEpistemicCategoryTests,
    runChoreographicCategoryTests,
    runDependentCategoryTests,
    runEffectsCategoryTests,
    runDecorativeCategoryTests,
    runCeremonialCategoryTests,
    runDyadicCategoryTests,
    runBridgeTests
  ]
  pure (concat results)
  where
    sequence : List (IO a) -> IO (List a)
    sequence [] = pure []
    sequence (x::xs) = do
      y <- x
      ys <- sequence xs
      pure (y::ys)
    
    concat : List (List a) -> List a
    concat = foldr (++) []

-- Run Tropical category tests
public export
runTropicalCategoryTests : IO (List (TestMetadata, TestResult))
runTropicalCategoryTests = do
  let tid = MkTestId "ProvenTests.TypeSafe.Tropical" "allTests" 0
  if runTropicalTests then
    pure [(tropicalClassification, Passed)]
  else
    pure [(tropicalClassification, Failed "Tropical tests failed")]

-- Run Epistemic category tests
public export
runEpistemicCategoryTests : IO (List (TestMetadata, TestResult))
runEpistemicCategoryTests = do
  let tid = MkTestId "ProvenTests.TypeSafe.Epistemic" "allTests" 0
  if runEpistemicTests then
    pure [(epistemicClassification, Passed)]
  else
    pure [(epistemicClassification, Failed "Epistemic tests failed")]

-- Run Choreographic category tests
public export
runChoreographicCategoryTests : IO (List (TestMetadata, TestResult))
runChoreographicCategoryTests = do
  if runChoreographicTests then
    pure [(choreographicClassification, Passed)]
  else
    pure [(choreographicClassification, Failed "Choreographic tests failed")]

-- Run Dependent category tests
public export
runDependentCategoryTests : IO (List (TestMetadata, TestResult))
runDependentCategoryTests = do
  if runDependentTests then
    pure [(dependentClassification, Passed)]
  else
    pure [(dependentClassification, Failed "Dependent tests failed")]

-- Run Effects category tests
public export
runEffectsCategoryTests : IO (List (TestMetadata, TestResult))
runEffectsCategoryTests = do
  if runEffectsTests then
    pure [(effectsClassification, Passed)]
  else
    pure [(effectsClassification, Failed "Effects tests failed")]

-- Run Decorative category tests
public export
runDecorativeCategoryTests : IO (List (TestMetadata, TestResult))
runDecorativeCategoryTests = do
  if runDecorativeTests then
    pure [(decorativeClassification, Passed)]
  else
    pure [(decorativeClassification, Failed "Decorative tests failed")]

-- Run Ceremonial category tests
public export
runCeremonialCategoryTests : IO (List (TestMetadata, TestResult))
runCeremonialCategoryTests = do
  if runCeremonialTests then
    pure [(ceremonialClassification, Passed)]
  else
    pure [(ceremonialClassification, Failed "Ceremonial tests failed")]

-- Run Dyadic category tests
public export
runDyadicCategoryTests : IO (List (TestMetadata, TestResult))
runDyadicCategoryTests = do
  if runDyadicTests then
    pure [(dyadicClassification, Passed)]
  else
    pure [(dyadicClassification, Failed "Dyadic tests failed")]

-- Run Bridge tests
public export
runBridgeTests : IO (List (TestMetadata, TestResult))
runBridgeTests = do
  if allBridgeTestsPass then
    pure [(bridgeClassification, Passed)]
  else
    pure [(bridgeClassification, Failed "Bridge tests failed")]

-- =============================================================================
-- COMPREHENSIVE TEST SUITE
-- =============================================================================

-- Run all tests including type-safe
public export
runAllTests : IO (List (TestMetadata, TestResult))
runAllTests = do
  self <- runSelfClassification >>= (\r => pure [r])
  typeSafe <- runTypeSafeTests
  pure (self ++ typeSafe)

-- Run comprehensive suite with reporting
public export
runComprehensiveSuite : IO ()
runComprehensiveSuite = do
  putStrLn "=== Running Comprehensive Test Suite ==="
  putStrLn ""
  
  allResults <- runAllTests
  
  -- Print summary
  putStrLn ""
  putStrLn "=== Test Summary ==="
  let passed = length (filter (\r => case snd r of Passed => True; _ => False) allResults)
      total = length allResults
  putStrLn ("Passed: " ++ show passed ++ "/" ++ show total)
  
  -- Check if all passed
  if passed == total then
    putStrLn "✅ All tests passed!"
  else
    putStrLn "❌ Some tests failed"
