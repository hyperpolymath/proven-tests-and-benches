-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafeTests.DecorativeTests

import ProvenTests.TypeSafe.Decorative
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- DECORATIVE TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================


-- Helper: Create test ID for decorative tests
private
decorativeTestId : Nat -> TestId
decorativeTestId n = MkTestId "ProvenTests.TypeSafe.DecorativeTests" ("test_" ++ show n) n

-- Test: Decoration preserves underlying value
public export
testDecorationPreservesValue : Test ProvisionallyProven
testDecorationPreservesValue = 
  provisionalTest (decorativeTestId 1) "Decoration preserves value" (
    assertTrue ((decorationPreservesValue Nat testDecorated) == 42) 
      "Decoration should preserve underlying value"
  )

-- Test: Decoration has metadata
public export
testDecorationHasMetadata : Test ProvisionallyProven
testDecorationHasMetadata = 
  provisionalTest (decorativeTestId 2) "Decoration has metadata" (
    assertTrue (decorationHasMetadata testDecorated) 
      "Decoration should have metadata"
  )

-- Test: Decoration is timestamped
public export
testDecorationIsTimestamped : Test ProvisionallyProven
testDecorationIsTimestamped = 
  provisionalTest (decorativeTestId 3) "Decoration is timestamped" (
    assertTrue (decorationIsTimestamped testDecorated) 
      "Decoration should have timestamp"
  )

-- Test: Decoration equality works
public export
testDecorationEquality : Test ProvisionallyProven
testDecorationEquality = 
  provisionalTest (decorativeTestId 4) "Decoration equality works" (
    assertTrue (decorationEquality Nat testDecorated testDecorated) 
      "Decoration equality should work correctly"
  )

-- Test: Decorator instance works
public export
testDecoratorInstanceWorks : Test ProvisionallyProven
testDecoratorInstanceWorks = 
  provisionalTest (decorativeTestId 5) "Decorator instance works" (
    assertTrue (decoratorInstanceWorks) 
      "Decorator instance should work"
  )

-- Test: All decorative tests pass
public export
testDecorativeAllTestsPass : Test ProvisionallyProven
testDecorativeAllTestsPass = 
  provisionalTest (decorativeTestId 6) "All decorative tests pass" (
    assertTrue (runDecorativeTests) 
      "All decorative type tests should pass"
  )

-- All decorative tests
public export
allDecorativeTests : List (Test ProvisionallyProven)
allDecorativeTests = [
    testDecorationPreservesValue,
    testDecorationHasMetadata,
    testDecorationIsTimestamped,
    testDecorationEquality,
    testDecoratorInstanceWorks,
    testDecorativeAllTestsPass
  ]
