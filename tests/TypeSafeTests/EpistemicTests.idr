-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.EpistemicTests

import ProvenTests.TypeSafe.Epistemic
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- EPISTEMIC TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================

%%access export

-- Helper: Create test ID for epistemic tests
private
epistemicTestId : Nat -> TestId
epistemicTestId n = MkTestId "ProvenTests.TypeSafe.EpistemicTests" ("test_" ++ show n) n

-- Test: Public information is accessible
public export
testEpistemicPublicAccessible : Test ProvisionallyProven
testEpistemicPublicAccessible = 
  provisionalTest (epistemicTestId 1) "Public information is accessible" (
    assertTrue (epistemicPublicAccessible publicKnowledge) 
      "Public information should always be accessible"
  )

-- Test: Secret information is hidden
public export
testEpistemicSecretHidden : Test ProvisionallyProven
testEpistemicSecretHidden = 
  provisionalTest (epistemicTestId 2) "Secret information is hidden" (
    assertTrue (epistemicSecretHidden secretKnowledge) 
      "Secret information should be properly restricted"
  )

-- Test: Information flow from public to secret is allowed
public export
testEpistemicFlowPublicToSecret : Test ProvisionallyProven
testEpistemicFlowPublicToSecret = 
  provisionalTest (epistemicTestId 3) "Information flow public to secret allowed" (
    assertTrue (epistemicFlowPublicToSecret publicKnowledge) 
      "Information should flow from public to secret"
  )

-- Test: Information flow from secret to public is NOT allowed
public export
testEpistemicNoFlowSecretToPublic : Test ProvisionallyProven
testEpistemicNoFlowSecretToPublic = 
  provisionalTest (epistemicTestId 4) "Information flow secret to public blocked" (
    assertTrue (epistemicNoFlowSecretToPublic secretKnowledge) 
      "Information should NOT flow from secret to public"
  )

-- Test: Classification levels are properly ordered
public export
testEpistemicClassificationOrdered : Test ProvisionallyProven
testEpistemicClassificationOrdered = 
  provisionalTest (epistemicTestId 5) "Classification levels are ordered" (
    assertTrue (epistemicClassificationOrdered classifiedLevels) 
      "Classification levels should be properly ordered"
  )

-- Test: Declassification maintains security
public export
testEpistemicDeclassificationSafe : Test ProvisionallyProven
testEpistemicDeclassificationSafe = 
  provisionalTest (epistemicTestId 6) "Declassification maintains security" (
    assertTrue (epistemicDeclassificationSafe secretKnowledge "CONFIDENTIAL") 
      "Declassification should only allow moving to lower levels"
  )

-- Test: All epistemic tests pass
public export
testEpistemicAllTestsPass : Test ProvisionallyProven
testEpistemicAllTestsPass = 
  provisionalTest (epistemicTestId 7) "All epistemic tests pass" (
    assertTrue (runEpistemicTests) 
      "All epistemic type tests should pass"
  )

-- All epistemic tests
public export
allEpistemicTests : List (Test ProvisionallyProven)
allEpistemicTests = [
    testEpistemicPublicAccessible,
    testEpistemicSecretHidden,
    testEpistemicFlowPublicToSecret,
    testEpistemicNoFlowSecretToPublic,
    testEpistemicClassificationOrdered,
    testEpistemicDeclassificationSafe,
    testEpistemicAllTestsPass
  ]
