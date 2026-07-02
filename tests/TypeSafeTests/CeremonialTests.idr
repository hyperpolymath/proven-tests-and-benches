-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module TypeSafeTests.CeremonialTests

import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- CEREMONIAL TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================


-- Helper: Create test ID for ceremonial tests
private
ceremonialTestId : Nat -> TestId
ceremonialTestId n = MkTestId "ProvenTests.TypeSafe.CeremonialTests" ("test_" ++ show n) n

-- Test: Ceremony starts with Initiate
public export
testCeremonialStartsProperly : ProvisionallyProvenTest
testCeremonialStartsProperly = 
  provisionalTest (ceremonialTestId 1) "Ceremony starts with Initiate" (
    assertTrue (ceremonyStartsProperly validCeremony) 
      "Valid ceremony should start with Initiate"
  )

-- Test: Ceremony ends with Complete
public export
testCeremonialEndsProperly : ProvisionallyProvenTest
testCeremonialEndsProperly = 
  provisionalTest (ceremonialTestId 2) "Ceremony ends with Complete" (
    assertTrue (ceremonyEndsProperly validCeremony) 
      "Valid ceremony should end with Complete"
  )

-- Test: All steps are valid
public export
testCeremonialAllStepsValid : ProvisionallyProvenTest
testCeremonialAllStepsValid = 
  provisionalTest (ceremonialTestId 3) "All ceremony steps are valid" (
    assertTrue (ceremonyAllStepsValid validCeremony) 
      "All ceremony steps should be valid"
  )

-- Test: Ceremony has required steps in order
public export
testCeremonialHasRequiredOrder : ProvisionallyProvenTest
testCeremonialHasRequiredOrder = 
  provisionalTest (ceremonialTestId 4) "Ceremony has required order" (
    assertTrue (ceremonyHasRequiredOrder validCeremony) 
      "Ceremony should have steps in required order"
  )

-- Test: All ceremonial tests pass
public export
testCeremonialAllTestsPass : ProvisionallyProvenTest
testCeremonialAllTestsPass = 
  provisionalTest (ceremonialTestId 5) "All ceremonial tests pass" (
    assertTrue (runCeremonialTests) 
      "All ceremonial type tests should pass"
  )

-- All ceremonial tests
public export
allCeremonialTests : List (ProvisionallyProvenTest)
allCeremonialTests = [
    testCeremonialStartsProperly,
    testCeremonialEndsProperly,
    testCeremonialAllStepsValid,
    testCeremonialHasRequiredOrder,
    testCeremonialAllTestsPass
  ]
