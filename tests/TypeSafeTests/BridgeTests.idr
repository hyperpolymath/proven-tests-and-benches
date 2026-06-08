-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.BridgeTests

import ProvenTests.TypeSafe.Bridge
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- BRIDGE TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================

%%access export

-- Helper: Create test ID for bridge tests
private
bridgeTestId : Nat -> TestId
bridgeTestId n = MkTestId "ProvenTests.TypeSafe.BridgeTests" ("test_" ++ show n) n

-- Test: Bridge connects to all categories
public export
testBridgeConnectsToAllCategories : Test ProvisionallyProven
testBridgeConnectsToAllCategories = 
  provisionalTest (bridgeTestId 1) "Bridge connects to all categories" (
    assertTrue (bridgeConnectsToAllCategories defaultEchoTypesBridge) 
      "Bridge should connect to all 9 categories"
  )

-- Test: Bridge version is valid
public export
testBridgeVersionValid : Test ProvisionallyProven
testBridgeVersionValid = 
  provisionalTest (bridgeTestId 2) "Bridge version is valid" (
    assertTrue (bridgeVersionValid defaultEchoTypesBridge) 
      "Bridge version should be valid"
  )

-- Test: Bridge repository is accessible
public export
testBridgeRepoAccessible : Test ProvisionallyProven
testBridgeRepoAccessible = 
  provisionalTest (bridgeTestId 3) "Bridge repository is accessible" (
    assertTrue (bridgeRepoAccessible defaultEchoTypesBridge) 
      "Bridge repository should be accessible"
  )

-- Test: Bridge supports echo-types category
public export
testBridgeSupportsEchoTypes : Test ProvisionallyProven
testBridgeSupportsEchoTypes = 
  provisionalTest (bridgeTestId 4) "Bridge supports echo-types category" (
    assertTrue (bridgeSupportsEchoTypes defaultEchoTypesBridge) 
      "Bridge should support echo-types category"
  )

-- Test: All type-safe tests run through bridge
public export
testBridgeAllTypeSafeTests : Test ProvisionallyProven
testBridgeAllTypeSafeTests = 
  provisionalTest (bridgeTestId 5) "All type-safe tests pass through bridge" (
    assertTrue (runAllTypeSafeTests) 
      "All type-safe tests should pass through bridge"
  )

-- Test: Echo type preserves type
public export
testEchoPreservesType : Test ProvisionallyProven
testEchoPreservesType = 
  provisionalTest (bridgeTestId 6) "Echo preserves type" (
    assertTrue (echoPreservesType (MkEcho 42)) 
      "Echo should preserve type"
  )

-- Test: Echo can be unwrapped
public export
testEchoUnwrappable : Test ProvisionallyProven
testEchoUnwrappable = 
  provisionalTest (bridgeTestId 7) "Echo can be unwrapped" (
    assertTrue (echoUnwrappable (MkEcho 42) == 42) 
      "Echo should be unwrappable"
  )

-- Test: All bridge tests pass
public export
testBridgeAllTestsPass : Test ProvisionallyProven
testBridgeAllTestsPass = 
  provisionalTest (bridgeTestId 8) "All bridge tests pass" (
    assertTrue (allBridgeTestsPass) 
      "All bridge tests should pass"
  )

-- All bridge tests
public export
allBridgeTests : List (Test ProvisionallyProven)
allBridgeTests = [
    testBridgeConnectsToAllCategories,
    testBridgeVersionValid,
    testBridgeRepoAccessible,
    testBridgeSupportsEchoTypes,
    testBridgeAllTypeSafeTests,
    testEchoPreservesType,
    testEchoUnwrappable,
    testBridgeAllTestsPass
  ]
