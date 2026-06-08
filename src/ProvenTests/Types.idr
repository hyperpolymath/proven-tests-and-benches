-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Types

-- Core types for the Proven-Tests framework

import Data.String
import Data.List
import Data.Maybe

-- =============================================================================
-- PROVENANCE CLASSIFICATION
-- =============================================================================

--/ Three-tier provenance classification for tests
public export
data ProvenStatus : Type where
  ActuallyProven : ProvenStatus
  ProvisionallyProven : ProvenStatus
  Unproven : ProvenStatus

-- Display instance for ProvenStatus
export
Show ProvenStatus where
  show ActuallyProven = "Actually-Proven"
  show ProvisionallyProven = "Provisionally-Proven"
  show Unproven = "Unproven"

-- =============================================================================
-- PROOF STEPS
-- =============================================================================

--/ A step in a proof ladder
public export
record ProofStep where
  constructor MkProofStep
  description : String
  proof_file   : Maybe String
  line_number  : Maybe Nat
  theorem     : Maybe String

-- =============================================================================
-- DESIGN PROOFS
-- =============================================================================

--/ Proof that the general design is safe
public export
record DesignSafetyProof where
  constructor MkDesignSafetyProof
  description      : String
  proof_technique  : String
  coverage         : List String
  limitations      : List String

-- =============================================================================
-- TYPE SAFETY CERTIFICATES
-- =============================================================================

--/ Certificate of type safety for a framework or component
public export
record TypeSafetyCertificate where
  constructor MkTypeSafetyCertificate
  kategoria_level : Nat
  type_system     : String
  verified_by     : String
  scope          : List String

-- =============================================================================
-- FRAMEWORK SAFETY
-- =============================================================================

--/ Proof that a framework is type-safe
public export
record FrameworkSafetyProof where
  constructor MkFrameworkSafetyProof
  framework_name : String
  type_safety    : TypeSafetyCertificate
  test_safety    : TypeSafetyCertificate
  documentation : String

-- =============================================================================
-- TEST IDENTIFICATION
-- =============================================================================

--/ Unique identifier for a test
public export
record TestId where
  constructor MkTestId
  module_path : String
  test_name   : String
  line_number : Nat

-- Display instance
export
Show TestId where
  show (MkTestId mp tn ln) = mp ++ "." ++ tn ++ " (line " ++ show ln ++ ")"

-- =============================================================================
-- TEST RESULTS
-- =============================================================================

--/ Result of running a test
public export
data TestResult : Type where
  Passed : TestResult
  Failed : String -> TestResult
  Error  : String -> TestResult
  Skipped : String -> TestResult

-- Display instance
export
Show TestResult where
  show Passed = "PASSED"
  show (Failed msg) = "FAILED: " ++ msg
  show (Error msg) = "ERROR: " ++ msg
  show (Skipped reason) = "SKIPPED: " ++ reason

-- =============================================================================
-- TYPE-SAFE TESTING CATEGORIES
-- =============================================================================

--/ Categories for type-safe testing
public export
data TypeSafeCategory : Type where
  Tropical     : TypeSafeCategory
  Epistemic    : TypeSafeCategory
  Choreographic : TypeSafeCategory
  Dependent    : TypeSafeCategory
  Effects      : TypeSafeCategory
  Decorative   : TypeSafeCategory
  Ceremonial   : TypeSafeCategory
  Dyadic       : TypeSafeCategory
  EchoTypes    : TypeSafeCategory

-- Display instance
export
Show TypeSafeCategory where
  show Tropical = "Tropical"
  show Epistemic = "Epistemic"
  show Choreographic = "Choreographic"
  show Dependent = "Dependent"
  show Effects = "Effects"
  show Decorative = "Decorative"
  show Ceremonial = "Ceremonial"
  show Dyadic = "Dyadic"
  show EchoTypes = "Echo-Types"

-- =============================================================================
-- TEST METADATA
-- =============================================================================

--/ Metadata about a test
public export
record TestMetadata where
  constructor MkTestMetadata
  test_id      : TestId
  description   : String
  category      : Maybe String
  aspect        : Maybe String
  typesafe_cat  : Maybe TypeSafeCategory
  proven_status : ProvenStatus
