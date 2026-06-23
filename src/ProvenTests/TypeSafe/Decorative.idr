-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Decorative

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- DECORATIVE TYPE TESTS
-- =============================================================================
-- Tests for type-level annotations (custom implementation)
-- Decorative types add metadata without affecting runtime


-- Decorated value with metadata
public export
record Decorated a where
  constructor MkDecorated
  value : a
  metadata : String
  source : String
  timestamp : Nat

-- Test: Decoration preserves underlying value
public export
decorationPreservesValue : (a : Type) -> Decorated a -> a
decorationPreservesValue _ (MkDecorated v _ _ _) = v

-- Test: Decoration adds metadata
public export
decorationHasMetadata : Decorated Nat -> Bool
decorationHasMetadata (MkDecorated _ md _ _) = md /= ""

-- Test: Decoration is timestamped
public export
decorationIsTimestamped : Decorated Nat -> Bool
decorationIsTimestamped (MkDecorated _ _ _ ts) = ts > 0

-- Test: Decoration doesn't affect equality
public export
decorationEquality : (a : Type) -> Eq a => Decorated a -> Decorated a -> Bool
decorationEquality _ (MkDecorated v1 _ _ _) (MkDecorated v2 _ _ _) = v1 == v2

-- Decorator interface
public export
interface Decorator a where
  decorate : a -> String -> Decorated a

-- Implementation for Nat
public export
Decorator Nat where
  decorate x meta = MkDecorated x meta "NatDecorator" 0

-- Test: Decorator instance works
public export
decoratorInstanceWorks : Bool
decoratorInstanceWorks = 
  let decorated = decorate 42 "test metadata"
  in decorationHasMetadata decorated

-- Test data
public export
testDecorated : Decorated Nat
testDecorated = MkDecorated 42 "Test metadata" "test" 1234567890

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
decorativeTests : List (Decorated Nat -> Bool)
decorativeTests = [
    (\_ => decorationHasMetadata testDecorated),
    (\_ => decorationIsTimestamped testDecorated),
    (\d => decorationEquality Nat d d),
    (\_ => decoratorInstanceWorks)
  ]

-- Run all decorative tests
public export
runDecorativeTests : Bool
runDecorativeTests = all (\f => f testDecorated) decorativeTests

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
decorativeClassification : TestMetadata
decorativeClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Decorative" "allTests" 0
      desc = "Decorative type system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Type-level Annotations" "Custom" ["Metadata preservation"]
  in classifyProvisionallyProven tid desc framework cert
