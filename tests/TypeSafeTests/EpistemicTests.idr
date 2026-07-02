-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module TypeSafeTests.EpistemicTests

import ProvenTests.TypeSafe.Epistemic
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- EPISTEMIC TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================


-- Helper: Create test ID for epistemic tests
private
epistemicTestId : Nat -> TestId
epistemicTestId n = MkTestId "ProvenTests.TypeSafe.EpistemicTests" ("test_" ++ show n) n

-- Test: Public information is accessible
public export
testEpistemicPublicAccessible : ProvisionallyProvenTest
testEpistemicPublicAccessible = 
  provisionalTest (epistemicTestId 1) "Public information is accessible" (
    assertTrue (epistemicPublicAccessible publicKnowledge) 
      "Public information should always be accessible"
  )

-- Test: Secret information is hidden
public export
testEpistemicSecretHidden : ProvisionallyProvenTest
testEpistemicSecretHidden = 
  provisionalTest (epistemicTestId 2) "Secret information is hidden" (
    assertTrue (epistemicSecretHidden secretKnowledge) 
      "Secret information should be properly restricted"
  )

-- Test: Information flow from public to secret is allowed.
-- Applied to the classified state, where both fields are populated and the
-- flow predicate is meaningful (see the note in ProvenTests.TypeSafe.Epistemic).
public export
testEpistemicFlowPublicToSecret : ProvisionallyProvenTest
testEpistemicFlowPublicToSecret =
  provisionalTest (epistemicTestId 3) "Information flow public to secret allowed" (
    assertTrue (epistemicFlowPublicToSecret secretKnowledge)
      "Information should flow from public to secret"
  )

-- Test: Information flow from secret to public is NOT allowed
public export
testEpistemicNoFlowSecretToPublic : ProvisionallyProvenTest
testEpistemicNoFlowSecretToPublic = 
  provisionalTest (epistemicTestId 4) "Information flow secret to public blocked" (
    assertTrue (epistemicNoFlowSecretToPublic secretKnowledge) 
      "Information should NOT flow from secret to public"
  )

-- Test: Classification levels are properly ordered
public export
testEpistemicClassificationOrdered : ProvisionallyProvenTest
testEpistemicClassificationOrdered = 
  provisionalTest (epistemicTestId 5) "Classification levels are ordered" (
    assertTrue (epistemicClassificationOrdered classifiedLevels) 
      "Classification levels should be properly ordered"
  )

-- Test: Declassification maintains security.
-- Applied from the PUBLIC state, the pairing where the predicate is meaningful
-- (see the note in ProvenTests.TypeSafe.Epistemic).
public export
testEpistemicDeclassificationSafe : ProvisionallyProvenTest
testEpistemicDeclassificationSafe =
  provisionalTest (epistemicTestId 6) "Declassification maintains security" (
    assertTrue (epistemicDeclassificationSafe publicKnowledge "CONFIDENTIAL")
      "Declassification should only allow moving to lower levels"
  )

-- Test: All epistemic tests pass
public export
testEpistemicAllTestsPass : ProvisionallyProvenTest
testEpistemicAllTestsPass = 
  provisionalTest (epistemicTestId 7) "All epistemic tests pass" (
    assertTrue (runEpistemicTests) 
      "All epistemic type tests should pass"
  )

-- All epistemic tests
public export
allEpistemicTests : List (ProvisionallyProvenTest)
allEpistemicTests = [
    testEpistemicPublicAccessible,
    testEpistemicSecretHidden,
    testEpistemicFlowPublicToSecret,
    testEpistemicNoFlowSecretToPublic,
    testEpistemicClassificationOrdered,
    testEpistemicDeclassificationSafe,
    testEpistemicAllTestsPass
  ]
