-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.DependentTests

import ProvenTests.TypeSafe.Dependent
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- DEPENDENT TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================

%%access export

-- Helper: Create test ID for dependent tests
private
dependentTestId : Nat -> TestId
dependentTestId n = MkTestId "ProvenTests.TypeSafe.DependentTests" ("test_" ++ show n) n

-- Test: Dependent pair maintains type correctness
public export
testDependentPairCorrect : Test ProvisionallyProven
testDependentPairCorrect = 
  provisionalTest (dependentTestId 1) "Dependent pair type correct" (
    assertTrue (dependentPairCorrect testDepPair) 
      "Dependent pair should maintain type correctness"
  )

-- Test: Vect length matches index
public export
testVectLengthCorrect : Test ProvisionallyProven
testVectLengthCorrect = 
  provisionalTest (dependentTestId 2) "Vect length matches index" (
    assertTrue (vectLengthCorrect testVect) 
      "Vect length should match its index"
  )

-- Test: Vect head is safe
public export
testVectHeadSafe : Test ProvisionallyProven
testVectHeadSafe = 
  provisionalTest (dependentTestId 3) "Vect head is safe" (
    assertTrue (vectHeadSafe testVect) 
      "Vect head access should be safe"
  )

-- Test: Dependent type preserves invariants
public export
testDependentInvariant : Test ProvisionallyProven
testDependentInvariant = 
  provisionalTest (dependentTestId 4) "Dependent type preserves invariants" (
    assertTrue (dependentInvariant 3 testVect) 
      "Dependent type should preserve invariants"
  )

-- Test: All dependent tests pass
public export
testDependentAllTestsPass : Test ProvisionallyProven
testDependentAllTestsPass = 
  provisionalTest (dependentTestId 5) "All dependent tests pass" (
    assertTrue (runDependentTests) 
      "All dependent type tests should pass"
  )

-- All dependent tests
public export
allDependentTests : List (Test ProvisionallyProven)
allDependentTests = [
    testDependentPairCorrect,
    testVectLengthCorrect,
    testVectHeadSafe,
    testDependentInvariant,
    testDependentAllTestsPass
  ]
