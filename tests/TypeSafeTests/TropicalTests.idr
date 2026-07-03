-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module TypeSafeTests.TropicalTests

import ProvenTests.TypeSafe.Tropical
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- TROPICAL TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================


-- Helper: Create test ID for tropical tests
private
tropicalTestId : Nat -> TestId
tropicalTestId n = MkTestId "ProvenTests.TypeSafe.TropicalTests" ("test_" ++ show n) n

-- Test: Tropical min is idempotent
public export
testTropicalMinIdempotent : ProvisionallyProvenTest
testTropicalMinIdempotent = 
  provisionalTest (tropicalTestId 1) "Tropical min is idempotent" (
    assertTrue (tropicalMinIdempotent exampleBound1) 
      "Tropical semiring min operation should be idempotent"
  )

-- Test: Tropical plus is commutative
public export
testTropicalPlusCommutative : ProvisionallyProvenTest
testTropicalPlusCommutative = 
  provisionalTest (tropicalTestId 2) "Tropical plus is commutative" (
    assertTrue (tropicalPlusCommutative exampleBound1 exampleBound2) 
      "Tropical semiring plus operation should be commutative"
  )

-- Test: Tropical min identity
public export
testTropicalMinIdentity : ProvisionallyProvenTest
testTropicalMinIdentity = 
  provisionalTest (tropicalTestId 3) "Tropical min identity property" (
    assertTrue (tropicalMinIdentity exampleBound1) 
      "min(x, 0) should equal x in tropical semiring"
  )

-- Test: Tropical plus identity
public export
testTropicalPlusIdentity : ProvisionallyProvenTest
testTropicalPlusIdentity = 
  provisionalTest (tropicalTestId 4) "Tropical plus identity property" (
    assertTrue (tropicalPlusIdentity exampleBound1) 
      "x + 0 should equal x in tropical semiring"
  )

-- Test: Resource bounds are non-negative
public export
testTropicalNonNegative : ProvisionallyProvenTest
testTropicalNonNegative = 
  provisionalTest (tropicalTestId 5) "Tropical resource bounds are non-negative" (
    assertTrue (tropicalNonNegative exampleBound1) 
      "All resource bounds should have non-negative values"
  )

-- Test: Combined bounds maintain validity
public export
testTropicalCombinedBounds : ProvisionallyProvenTest
testTropicalCombinedBounds = 
  provisionalTest (tropicalTestId 6) "Tropical combined bounds maintain validity" (
    assertTrue (tropicalCombinedBounds exampleBound1 exampleBound2) 
      "Combining resource bounds should maintain non-negativity"
  )

-- Test: Order preserving property
public export
testTropicalOrderPreserving : ProvisionallyProvenTest
testTropicalOrderPreserving = 
  provisionalTest (tropicalTestId 7) "Tropical operations preserve order" (
    assertTrue (tropicalOrderPreserving exampleBound1 exampleBound2) 
      "Tropical operations should preserve ordering relationships"
  )

-- All tropical tests
public export
allTropicalTests : List (ProvisionallyProvenTest)
allTropicalTests = [
    testTropicalMinIdempotent,
    testTropicalPlusCommutative,
    testTropicalMinIdentity,
    testTropicalPlusIdentity,
    testTropicalNonNegative,
    testTropicalCombinedBounds,
    testTropicalOrderPreserving
  ]
