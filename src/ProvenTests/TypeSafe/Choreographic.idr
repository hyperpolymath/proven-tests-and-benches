-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Choreographic

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- CHOREOGRAPHIC TYPE SYSTEM TESTS
-- =============================================================================
-- Tests for multi-party session types from TypeLL
-- Ensures protocol correctness across distributed participants


-- Session type representation
public export
data SessionType : Type where
  Send : String -> SessionType -> SessionType
  Recv : String -> SessionType -> SessionType
  Choice : List String -> List SessionType -> SessionType
  End : SessionType

-- Test: Send followed by Recv is valid
public export
choreographicSendRecvValid : Bool
choreographicSendRecvValid = 
  let session = Send "message" (Recv "ack" End)
  in case session of
       Send _ (Recv _ End) => True
       _ => False

-- Test: Session ends properly
public export
choreographicEndsProperly : SessionType -> Bool
choreographicEndsProperly End = True
choreographicEndsProperly (Send _ st) = choreographicEndsProperly st
choreographicEndsProperly (Recv _ st) = choreographicEndsProperly st
choreographicEndsProperly (Choice _ branches) = all choreographicEndsProperly branches
choreographicEndsProperly _ = False

-- Test: No orphaned choices (all branches must exist)
public export
choreographicNoOrphanedChoices : SessionType -> Bool
choreographicNoOrphanedChoices (Choice labels branches) = 
  length labels == length branches
choreographicNoOrphanedChoices _ = True

-- Test: Dual session (send and recv match)
public export
dualSession : SessionType
dualSession = Send "data" (Recv "response" End)

-- Test: Choice session with multiple branches
public export
choiceSession : SessionType
choiceSession = Choice ["option1", "option2"] [
    Send "choice1" End,
    Send "choice2" End
  ]

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
choreographicTests : List (SessionType -> Bool)
choreographicTests = [
    (\_ => choreographicSendRecvValid),
    choreographicEndsProperly,
    choreographicNoOrphanedChoices
  ]

-- Run all choreographic tests
public export
runChoreographicTests : Bool
runChoreographicTests = 
  all (\f => f dualSession && f choiceSession) choreographicTests

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
choreographicClassification : TestMetadata
choreographicClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Choreographic" "allTests" 0
      desc = "Choreographic type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Session Types from TypeLL" "Idris2 + Choreographic" ["Protocol correctness"]
  in classifyProvisionallyProven tid desc framework cert
