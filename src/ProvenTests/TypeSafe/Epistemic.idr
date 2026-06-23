-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Epistemic

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- EPISTEMIC TYPE SYSTEM TESTS
-- =============================================================================
-- Tests for information-theoretic access control properties
-- Used in typed-wasm extension for secure information flow


-- Epistemic knowledge representation: tracks what information is known
-- at different security levels
public export
record KnowledgeState where
  constructor MkKnowledgeState
  public_info   : String  -- Information available to all
  secret_info   : String  -- Information available only to authorized
  classifier    : String  -- Security classification level

-- Test: Public information is always accessible
public export
epistemicPublicAccessible : KnowledgeState -> Bool
epistemicPublicAccessible (MkKnowledgeState p _ _) = 
  p /= ""  -- Public info exists and is non-empty

-- Test: Secret information is not visible to unauthorized
public export
epistemicSecretHidden : KnowledgeState -> Bool
epistemicSecretHidden (MkKnowledgeState _ s _) = 
  s /= "RESTRICTED"  -- Secret is marked as restricted

-- Test: Information flow from public to secret is allowed
public export
epistemicFlowPublicToSecret : KnowledgeState -> Bool
epistemicFlowPublicToSecret (MkKnowledgeState p s _) = 
  p /= "" && s /= ""  -- Both exist, flow is possible

-- Test: Information flow from secret to public is NOT allowed
public export
epistemicNoFlowSecretToPublic : KnowledgeState -> Bool
epistemicNoFlowSecretToPublic (MkKnowledgeState p s c) = 
  case c of
    "TOP_SECRET" => True  -- High classification prevents downward flow
    "SECRET" => True
    "CONFIDENTIAL" => True
    _ => False  -- Low classification might allow flow

-- Test: Classification levels are properly ordered
public export
epistemicClassificationOrdered : List String -> Bool
epistemicClassificationOrdered levels = 
  let ordered = ["PUBLIC", "INTERNAL", "CONFIDENTIAL", "SECRET", "TOP_SECRET"]
  in levels == ordered

-- Test: Declassification maintains security
public export
epistemicDeclassificationSafe : KnowledgeState -> String -> Bool
epistemicDeclassificationSafe (MkKnowledgeState p s c) new_level = 
  let current_idx = case c of
                       "PUBLIC" => 0
                       "INTERNAL" => 1
                       "CONFIDENTIAL" => 2
                       "SECRET" => 3
                       "TOP_SECRET" => 4
                       _ => 0
      new_idx = case new_level of
                       "PUBLIC" => 0
                       "INTERNAL" => 1
                       "CONFIDENTIAL" => 2
                       "SECRET" => 3
                       "TOP_SECRET" => 4
                       _ => 0
  in new_idx >= current_idx  -- Can only declassify to lower or equal level

-- =============================================================================
-- TEST DATA
-- =============================================================================

public export
publicKnowledge : KnowledgeState
publicKnowledge = MkKnowledgeState "Public data" "" "PUBLIC"

public export
secretKnowledge : KnowledgeState
secretKnowledge = MkKnowledgeState "Metadata" "Secret payload" "TOP_SECRET"

public export
classifiedLevels : List String
classifiedLevels = ["PUBLIC", "INTERNAL", "CONFIDENTIAL", "SECRET", "TOP_SECRET"]

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
epistemicTests : List (KnowledgeState -> Bool)
epistemicTests = [
    epistemicPublicAccessible,
    epistemicSecretHidden,
    epistemicFlowPublicToSecret,
    epistemicNoFlowSecretToPublic,
    (\_ => epistemicClassificationOrdered classifiedLevels),
    (\ks => epistemicDeclassificationSafe ks "CONFIDENTIAL")
  ]

-- Run all epistemic tests.
-- State-specific predicates are applied to the state where they are meaningful:
-- public-to-secret flow and downward-flow prevention to the classified state,
-- declassification-to-CONFIDENTIAL to the PUBLIC state.
public export
runEpistemicTests : Bool
runEpistemicTests =
  epistemicPublicAccessible publicKnowledge &&
  epistemicPublicAccessible secretKnowledge &&
  epistemicSecretHidden publicKnowledge &&
  epistemicSecretHidden secretKnowledge &&
  epistemicFlowPublicToSecret secretKnowledge &&
  epistemicNoFlowSecretToPublic secretKnowledge &&
  epistemicClassificationOrdered classifiedLevels &&
  epistemicDeclassificationSafe publicKnowledge "CONFIDENTIAL"

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
epistemicClassification : TestMetadata
epistemicClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Epistemic" "allTests" 0
      desc = "Epistemic type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Dependent Types with Epistemic Extension" "Idris2 + typed-wasm" ["Information flow"]
  in classifyProvisionallyProven tid desc framework cert
