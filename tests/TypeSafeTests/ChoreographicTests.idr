-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.ChoreographicTests

import ProvenTests.TypeSafe.Choreographic
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- CHOREOGRAPHIC TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================

%%access export

-- Helper: Create test ID for choreographic tests
private
choreographicTestId : Nat -> TestId
choreographicTestId n = MkTestId "ProvenTests.TypeSafe.ChoreographicTests" ("test_" ++ show n) n

-- Test: Send followed by Recv is valid
public export
testChoreographicSendRecvValid : Test ProvisionallyProven
testChoreographicSendRecvValid = 
  provisionalTest (choreographicTestId 1) "Send followed by Recv is valid" (
    assertTrue (choreographicSendRecvValid) 
      "Send followed by Recv should be a valid session"
  )

-- Test: Session ends properly
public export
testChoreographicEndsProperly : Test ProvisionallyProven
testChoreographicEndsProperly = 
  provisionalTest (choreographicTestId 2) "Session ends properly" (
    assertTrue (choreographicEndsProperly dualSession) 
      "Dual session should end properly"
  )

-- Test: No orphaned choices
public export
testChoreographicNoOrphanedChoices : Test ProvisionallyProven
testChoreographicNoOrphanedChoices = 
  provisionalTest (choreographicTestId 3) "No orphaned choices" (
    assertTrue (choreographicNoOrphanedChoices choiceSession) 
      "Choice session should have no orphaned branches"
  )

-- Test: All choreographic tests pass
public export
testChoreographicAllTestsPass : Test ProvisionallyProven
testChoreographicAllTestsPass = 
  provisionalTest (choreographicTestId 4) "All choreographic tests pass" (
    assertTrue (runChoreographicTests) 
      "All choreographic type tests should pass"
  )

-- All choreographic tests
public export
allChoreographicTests : List (Test ProvisionallyProven)
allChoreographicTests = [
    testChoreographicSendRecvValid,
    testChoreographicEndsProperly,
    testChoreographicNoOrphanedChoices,
    testChoreographicAllTestsPass
  ]
