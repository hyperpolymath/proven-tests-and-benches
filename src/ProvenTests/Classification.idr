-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Classification

import ProvenTests.Types
import Data.List1

-- =============================================================================
-- ACTUALLY-PROVEN CLASSIFICATION
-- =============================================================================

--/ Evidence for Actually-Proven classification
public export
record ActuallyProvenEvidence where
  constructor MkActuallyProvenEvidence
  proof_ladder      : List ProofStep
  design_proof      : DesignSafetyProof
  type_safety       : TypeSafetyCertificate
  formal_verification : List String
  coverage          : List String

--/ Classifier for Actually-Proven tests
public export
isActuallyProven : TestMetadata -> Bool
isActuallyProven m = case statusOf (provenance m) of
  ActuallyProven => True
  _ => False

--/ Create an Actually-Proven classification
public export
classifyActuallyProven :
     TestId -> String -> List1 ProofStep -> DesignSafetyProof ->
     TypeSafetyCertificate -> TestMetadata
classifyActuallyProven tid desc ladder design type_safe =
  MkTestMetadata tid desc Nothing Nothing Nothing
    (PActuallyProven (MkActualEvidence ladder design type_safe))

-- =============================================================================
-- PROVISIONALLY-PROVEN CLASSIFICATION
-- =============================================================================

--/ Evidence for Provisionally-Proven classification
public export
record ProvisionallyProvenEvidence where
  constructor MkProvisionallyProvenEvidence
  framework_safety  : FrameworkSafetyProof
  test_safety        : TypeSafetyCertificate
  type_appropriateness : List String

--/ Classifier for Provisionally-Proven tests
public export
isProvisionallyProven : TestMetadata -> Bool
isProvisionallyProven m = case statusOf (provenance m) of
  ProvisionallyProven => True
  _ => False

--/ Create a Provisionally-Proven classification
public export
classifyProvisionallyProven :
     TestId -> String -> FrameworkSafetyProof -> TypeSafetyCertificate -> TestMetadata
classifyProvisionallyProven tid desc framework test_safe =
  MkTestMetadata tid desc Nothing Nothing Nothing
    (PProvisionallyProven (MkProvisionalEvidence framework test_safe))

-- =============================================================================
-- UNPROVEN CLASSIFICATION
-- =============================================================================

--/ Classifier for Unproven tests
public export
isUnproven : TestMetadata -> Bool
isUnproven m = case statusOf (provenance m) of
  Unproven => True
  _ => False

--/ Create an Unproven classification
public export
classifyUnproven : TestId -> String -> TestMetadata
classifyUnproven tid desc =
  MkTestMetadata tid desc Nothing Nothing Nothing PUnproven

-- =============================================================================
-- CLASSIFICATION UTILITIES
-- =============================================================================

--/ Get the proven status
public export
getProvenStatus : TestMetadata -> ProvenStatus
getProvenStatus m = statusOf (provenance m)

--/ Promote from Unproven to Provisionally-Proven
public export
promoteToProvisionallyProven :
     TestMetadata -> FrameworkSafetyProof -> TypeSafetyCertificate -> Maybe TestMetadata
promoteToProvisionallyProven meta fw ts = case provenance meta of
  PUnproven => Just ({ provenance := PProvisionallyProven (MkProvisionalEvidence fw ts) } meta)
  _         => Nothing

--/ Promote from Provisionally-Proven to Actually-Proven
public export
promoteToActuallyProven :
     TestMetadata -> List1 ProofStep -> DesignSafetyProof ->
     TypeSafetyCertificate -> Maybe TestMetadata
promoteToActuallyProven meta ladder design ts = case provenance meta of
  PProvisionallyProven _ =>
    Just ({ provenance := PActuallyProven (MkActualEvidence ladder design ts) } meta)
  _ => Nothing

-- =============================================================================
-- CONSTRUCTORS
-- =============================================================================

public export
emptyProofLadder : List ProofStep
emptyProofLadder = []

public export
addProofStep : ProofStep -> List ProofStep -> List ProofStep
addProofStep step ladder = ladder ++ [step]

public export
proofStep : String -> Maybe String -> Maybe Nat -> Maybe String -> ProofStep
proofStep desc file line theorem = MkProofStep desc file line theorem

public export
designProof : String -> String -> List String -> List String -> DesignSafetyProof
designProof desc technique coverage limitations = MkDesignSafetyProof desc technique coverage limitations

public export
typeSafetyCert : Nat -> String -> String -> List String -> TypeSafetyCertificate
typeSafetyCert level type_system verified scope = MkTypeSafetyCertificate level type_system verified scope

public export
frameworkProof : String -> TypeSafetyCertificate -> TypeSafetyCertificate -> String -> FrameworkSafetyProof
frameworkProof name type_safe test_safe docs = MkFrameworkSafetyProof name type_safe test_safe docs

-- =============================================================================
-- PROVEN-TESTS SELF-CLASSIFICATION
-- =============================================================================

--/ Proven-Tests framework's own safety proof
public export
provenTestsFrameworkProof : FrameworkSafetyProof
provenTestsFrameworkProof =
  let type_safe_cert = typeSafetyCert 6 "Dependent Types" "Idris2 type checker" 
        ["Test framework", "Classification system"]
      test_safe_cert = typeSafetyCert 6 "Dependent Types" "Idris2 type checker" 
        ["Test execution", "Result reporting"]
  in frameworkProof "Proven-Tests" type_safe_cert test_safe_cert "See docs/TAXONOMY.adoc"

--/ Proven-Tests framework is Provisionally-Proven
public export
provenTestsMetadata : TestMetadata
provenTestsMetadata =
  let tid = MkTestId "ProvenTests" "Framework" 0
      desc = "Proven-Tests framework self-classification"
  in classifyProvisionallyProven tid desc provenTestsFrameworkProof 
       (typeSafetyCert 6 "Dependent Types" "Idris2" ["Framework"])
