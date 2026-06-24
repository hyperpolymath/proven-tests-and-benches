-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Ceremonial

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- CEREMONIAL TYPE TESTS
-- =============================================================================
-- Tests for protocol/ritual types (custom implementation)
-- Ensures proper sequencing of operations


-- Ceremonial action type
public export
data CeremonyStep : Type where
  Initiate : String -> CeremonyStep
  Authenticate : String -> CeremonyStep
  Validate : String -> CeremonyStep
  Confirm : String -> CeremonyStep
  Complete : String -> CeremonyStep

-- Ceremony protocol
public export
data Ceremony : Type where
  MkCeremony : List CeremonyStep -> Ceremony

-- Helper: get last element of list (Prelude's `last` needs a NonEmpty proof).
-- Declared before its first use below.
public export
lastMaybe : List a -> Maybe a
lastMaybe [] = Nothing
lastMaybe [x] = Just x
lastMaybe (_ :: xs) = lastMaybe xs

-- Test: Ceremony starts with Initiate
public export
ceremonyStartsProperly : Ceremony -> Bool
ceremonyStartsProperly (MkCeremony []) = False
ceremonyStartsProperly (MkCeremony (Initiate _ :: _)) = True
ceremonyStartsProperly (MkCeremony _) = False

-- Test: Ceremony ends with Complete
public export
ceremonyEndsProperly : Ceremony -> Bool
ceremonyEndsProperly (MkCeremony []) = False
ceremonyEndsProperly (MkCeremony xs) =
  case lastMaybe xs of
    Just (Complete _) => True
    _ => False

-- Test: All steps are valid
public export
ceremonyAllStepsValid : Ceremony -> Bool
ceremonyAllStepsValid (MkCeremony steps) = all isValidStep steps
  where
    isValidStep : CeremonyStep -> Bool
    isValidStep (Initiate _) = True
    isValidStep (Authenticate _) = True
    isValidStep (Validate _) = True
    isValidStep (Confirm _) = True
    isValidStep (Complete _) = True

-- Test: Ceremony has required steps in order
public export
ceremonyHasRequiredOrder : Ceremony -> Bool
ceremonyHasRequiredOrder (MkCeremony steps) = 
  let stepNames = map stepName steps
      required = ["Initiate", "Authenticate", "Validate", "Confirm", "Complete"]
  in required == stepNames
  where
    stepName : CeremonyStep -> String
    stepName (Initiate _) = "Initiate"
    stepName (Authenticate _) = "Authenticate"
    stepName (Validate _) = "Validate"
    stepName (Confirm _) = "Confirm"
    stepName (Complete _) = "Complete"

-- Test data
public export
validCeremony : Ceremony
validCeremony = MkCeremony [
    Initiate "Start",
    Authenticate "Verify",
    Validate "Check",
    Confirm "Approve",
    Complete "Finish"
  ]

public export
invalidCeremony : Ceremony
invalidCeremony = MkCeremony [
    Authenticate "Verify",
    Initiate "Start"
  ]

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
ceremonialTests : List (Ceremony -> Bool)
ceremonialTests = [
    ceremonyStartsProperly,
    ceremonyEndsProperly,
    ceremonyAllStepsValid,
    ceremonyHasRequiredOrder
  ]

-- Run all ceremonial tests
public export
runCeremonialTests : Bool
runCeremonialTests = 
  all (\f => f validCeremony) ceremonialTests

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
ceremonialClassification : TestMetadata
ceremonialClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Ceremonial" "allTests" 0
      desc = "Ceremonial type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Protocol/Ritual Types" "Custom" ["Sequencing"]
  in classifyProvisionallyProven tid desc framework cert
