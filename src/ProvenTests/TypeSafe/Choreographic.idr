-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
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

-- Test: Send followed by Recv is valid.
--
-- NOTE (2026-08-07): this used to construct its own input and immediately
-- pattern-match it — a closed literal round-trip with no free variable, so it
-- could only ever return True. It is now a predicate on a session, exercised
-- below against both a conforming and a non-conforming fixture.
public export
choreographicSendRecvValid : SessionType -> Bool
choreographicSendRecvValid (Send _ (Recv _ End)) = True
choreographicSendRecvValid _ = False

-- Test: Session ends properly.
--
-- NOTE: the four clauses below are exhaustive over SessionType's four
-- constructors. A fifth catch-all `_ = False` sat here until 2026-08-07 —
-- unreachable dead code that read as a rejection path.
public export
choreographicEndsProperly : SessionType -> Bool
choreographicEndsProperly End = True
choreographicEndsProperly (Send _ st) = choreographicEndsProperly st
choreographicEndsProperly (Recv _ st) = choreographicEndsProperly st
choreographicEndsProperly (Choice _ branches) = all choreographicEndsProperly branches

-- Test: No orphaned choices — every label has a branch, checked RECURSIVELY.
--
-- NOTE (2026-08-07): this used to return True for every non-Choice value and
-- never descend. Two consequences: applying it to `dualSession` (a Send) was
-- vacuous, and a malformed Choice nested inside a Send was invisible to it.
-- `nestedOrphanedSession` below is exactly that case.
public export
choreographicNoOrphanedChoices : SessionType -> Bool
choreographicNoOrphanedChoices End = True
choreographicNoOrphanedChoices (Send _ st) = choreographicNoOrphanedChoices st
choreographicNoOrphanedChoices (Recv _ st) = choreographicNoOrphanedChoices st
choreographicNoOrphanedChoices (Choice labels branches) =
  length labels == length branches && all choreographicNoOrphanedChoices branches

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
    choreographicEndsProperly,
    choreographicNoOrphanedChoices
  ]

-- =============================================================================
-- NEGATIVE FIXTURES
-- =============================================================================
-- Sessions that must be REJECTED. Without these, a predicate that returned True
-- constantly would pass every test above — which is precisely what
-- `choreographicNoOrphanedChoices` did for any non-Choice input.

--/ Two labels, one branch.
public export
orphanedChoiceSession : SessionType
orphanedChoiceSession = Choice ["option1", "option2"] [ Send "choice1" End ]

--/ The same fault, nested inside a Send. The old non-recursive predicate
--/ returned True for this without ever looking at the Choice.
public export
nestedOrphanedSession : SessionType
nestedOrphanedSession = Send "outer" (Choice ["a", "b"] [ End ])

public export
orphanedChoiceRejected : Bool
orphanedChoiceRejected = not (choreographicNoOrphanedChoices orphanedChoiceSession)

public export
nestedOrphanRejected : Bool
nestedOrphanRejected = not (choreographicNoOrphanedChoices nestedOrphanedSession)

-- Run all choreographic tests: the parametric predicates against two conforming
-- sessions, the Send/Recv shape check in both directions, and the two orphaned
-- fixtures that must be rejected.
public export
runChoreographicTests : Bool
runChoreographicTests =
     all (\f => f dualSession && f choiceSession) choreographicTests
  && choreographicSendRecvValid dualSession
  && not (choreographicSendRecvValid choiceSession)
  && orphanedChoiceRejected
  && nestedOrphanRejected

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
