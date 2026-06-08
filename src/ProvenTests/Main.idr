-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module Main

import ProvenTests.Runners
import ProvenTests.TypeSafeTests.TropicalTests
import ProvenTests.TypeSafeTests.EpistemicTests
import ProvenTests.TypeSafeTests.ChoreographicTests
import ProvenTests.TypeSafeTests.CeremonialTests
import ProvenTests.TypeSafeTests.DependentTests
import ProvenTests.TypeSafeTests.EffectsTests
import ProvenTests.TypeSafeTests.DecorativeTests
import ProvenTests.TypeSafeTests.DyadicTests
import ProvenTests.TypeSafeTests.BridgeTests

-- =============================================================================
-- MAIN ENTRY POINT
-- =============================================================================

--/ Main entry point for the Proven-Tests framework
public export
main : IO ()
main = do
  -- Run the comprehensive test suite
  runComprehensiveSuite
  
  -- Additionally run all individual test suites
  putStrLn ""
  putStrLn "=== Running Individual Test Suites ==="
  putStrLn ""
  
  -- Run all tropical tests
  mapM_ runTest allTropicalTests
  
  -- Run all epistemic tests
  mapM_ runTest allEpistemicTests
  
  -- Run all choreographic tests
  mapM_ runTest allChoreographicTests
  
  -- Run all ceremonial tests
  mapM_ runTest allCeremonialTests
  
  -- Run all dependent tests
  mapM_ runTest allDependentTests
  
  -- Run all effects tests
  mapM_ runTest allEffectsTests
  
  -- Run all decorative tests
  mapM_ runTest allDecorativeTests
  
  -- Run all dyadic tests
  mapM_ runTest allDyadicTests
  
  -- Run all bridge tests
  mapM_ runTest allBridgeTests
  
  putStrLn ""
  putStrLn "=== All Test Suites Complete ==="
