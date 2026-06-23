-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.CeremonialTests

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
testCeremonialStartsProperly : Test ProvisionallyProven
testCeremonialStartsProperly = 
  provisionalTest (ceremonialTestId 1) "Ceremony starts with Initiate" (
    assertTrue (ceremonyStartsProperly validCeremony) 
      "Valid ceremony should start with Initiate"
  )

-- Test: Ceremony ends with Complete
public export
testCeremonialEndsProperly : Test ProvisionallyProven
testCeremonialEndsProperly = 
  provisionalTest (ceremonialTestId 2) "Ceremony ends with Complete" (
    assertTrue (ceremonyEndsProperly validCeremony) 
      "Valid ceremony should end with Complete"
  )

-- Test: All steps are valid
public export
testCeremonialAllStepsValid : Test ProvisionallyProven
testCeremonialAllStepsValid = 
  provisionalTest (ceremonialTestId 3) "All ceremony steps are valid" (
    assertTrue (ceremonyAllStepsValid validCeremony) 
      "All ceremony steps should be valid"
  )

-- Test: Ceremony has required steps in order
public export
testCeremonialHasRequiredOrder : Test ProvisionallyProven
testCeremonialHasRequiredOrder = 
  provisionalTest (ceremonialTestId 4) "Ceremony has required order" (
    assertTrue (ceremonyHasRequiredOrder validCeremony) 
      "Ceremony should have steps in required order"
  )

-- Test: All ceremonial tests pass
public export
testCeremonialAllTestsPass : Test ProvisionallyProven
testCeremonialAllTestsPass = 
  provisionalTest (ceremonialTestId 5) "All ceremonial tests pass" (
    assertTrue (runCeremonialTests) 
      "All ceremonial type tests should pass"
  )

-- All ceremonial tests
public export
allCeremonialTests : List (Test ProvisionallyProven)
allCeremonialTests = [
    testCeremonialStartsProperly,
    testCeremonialEndsProperly,
    testCeremonialAllStepsValid,
    testCeremonialHasRequiredOrder,
    testCeremonialAllTestsPass
  ]
