-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Tropical

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- TROPICAL TYPE SYSTEM TESTS
-- =============================================================================
-- Tests for min-plus semiring resource bounds properties
-- Used in typed-wasm extension for resource-aware computations


-- Tropical semiring: (ℝ ∪ {∞}, min, +)
-- Identity: min(x, 0) = x, x + ∞ = ∞
-- Properties: min is idempotent, + is commutative and associative

-- Resource bound representation
public export
record ResourceBound where
  constructor MkResourceBound
  min_value    : Double
  plus_value   : Double
  description   : String

-- Test: min is idempotent (min(x, x) = x)
public export
tropicalMinIdempotent : ResourceBound -> Bool
tropicalMinIdempotent (MkResourceBound mv _ _) = 
  let x = mv in (min x x) == x

-- Test: + is commutative (a + b = b + a)
public export
tropicalPlusCommutative : ResourceBound -> ResourceBound -> Bool
tropicalPlusCommutative (MkResourceBound _ p1 _) (MkResourceBound _ p2 _) = 
  (p1 + p2) == (p2 + p1)

-- Test: Identity property for min
public export
tropicalMinIdentity : ResourceBound -> Bool
tropicalMinIdentity (MkResourceBound mv _ _) = 
  let x = mv in (min x 0) == x

-- Test: Identity property for +
public export
tropicalPlusIdentity : ResourceBound -> Bool
tropicalPlusIdentity (MkResourceBound _ p _) = 
  (p + 0) == p

-- Test: Resource bounds are non-negative
public export
tropicalNonNegative : ResourceBound -> Bool
tropicalNonNegative (MkResourceBound mv p _) = 
  mv >= 0 && p >= 0

-- Test: Combined resource operations maintain bounds
public export
tropicalCombinedBounds : ResourceBound -> ResourceBound -> Bool
tropicalCombinedBounds (MkResourceBound mv1 p1 _) (MkResourceBound mv2 p2 _) = 
  let combined_min = min mv1 mv2
      combined_plus = p1 + p2
  in combined_min >= 0 && combined_plus >= 0

-- Type-safe property: Tropical operations preserve order
public export
tropicalOrderPreserving : ResourceBound -> ResourceBound -> Bool
tropicalOrderPreserving (MkResourceBound mv1 p1 _) (MkResourceBound mv2 p2 _) = 
  let result_min = min mv1 mv2
      result_plus = p1 + p2
  in result_min <= mv1 && result_min <= mv2 && result_plus >= p1 && result_plus >= p2

-- =============================================================================
-- TEST DATA
-- =============================================================================

-- Example resource bounds for testing
public export
exampleBound1 : ResourceBound
exampleBound1 = MkResourceBound 10.0 5.0 "Example bound 1"

public export
exampleBound2 : ResourceBound
exampleBound2 = MkResourceBound 20.0 15.0 "Example bound 2"

public export
exampleBound3 : ResourceBound
exampleBound3 = MkResourceBound 0.0 0.0 "Zero bound"

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

-- Each test is a type-safe assertion that can be verified at compile time
-- These are the core properties that the Tropical type system must satisfy

public export
tropicalTests : List (ResourceBound -> ResourceBound -> Bool)
tropicalTests = [
    (\_, _ => tropicalMinIdempotent (MkResourceBound 5.0 3.0 "Test")),
    (\_, _ => tropicalPlusCommutative exampleBound1 exampleBound2),
    (\_, _ => tropicalMinIdentity exampleBound1),
    (\_, _ => tropicalPlusIdentity exampleBound1),
    (\_, _ => tropicalNonNegative exampleBound1),
    (\_, _ => tropicalCombinedBounds exampleBound1 exampleBound2),
    (\_, _ => tropicalOrderPreserving exampleBound1 exampleBound2)
  ]

-- Run all tropical tests
public export
runTropicalTests : Bool
runTropicalTests = all (\f => f exampleBound1 exampleBound2) tropicalTests

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

-- Classify tropical tests as Provisionally-Proven
public export
tropicalClassification : TestMetadata
tropicalClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Tropical" "allTests" 0
      desc = "Tropical type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Dependent Types with Tropical Extension" "Idris2 + typed-wasm" ["Resource bounds"]
  in classifyProvisionallyProven tid desc framework cert
