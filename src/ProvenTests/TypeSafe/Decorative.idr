-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
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

--/ Same underlying value, a different annotation. This is the pair the
--/ "decoration does not affect equality" property is actually about.
public export
reDecorate : Decorated Nat -> String -> Decorated Nat
reDecorate (MkDecorated v _ s ts) md = MkDecorated v md s ts

-- NOTE (2026-08-07): three of the four entries below ignored their argument `d`
-- and re-read the module-level constant `testDecorated` — and since
-- `runDecorativeTests` applies the list *to* `testDecorated`, the "test list
-- applied to an input" shape was decorative. The fourth,
-- `\d => decorationEquality Nat d d`, was reflexivity on (==): constant True for
-- any lawful Eq instance. The entries are now genuinely parametric, and the
-- equality property compares two DIFFERENTLY-decorated values.
public export
decorativeTests : List (Decorated Nat -> Bool)
decorativeTests = [
    decorationHasMetadata,
    decorationIsTimestamped,
    (\d => decorationEquality Nat d (reDecorate d "a different annotation")),
    (\_ => decoratorInstanceWorks)
  ]

--/ Different underlying values must NOT compare equal, however identical their
--/ decoration. Without this, a `decorationEquality` that returned True
--/ constantly would satisfy every test above.
public export
differentValuesNotEqual : Bool
differentValuesNotEqual =
  not (decorationEquality Nat testDecorated
        (MkDecorated 43 "Test metadata" "test" 1234567890))

--/ An undecorated value must be rejected by the metadata predicate.
public export
emptyMetadataRejected : Bool
emptyMetadataRejected = not (decorationHasMetadata (reDecorate testDecorated ""))

-- Run all decorative tests, plus the two negative fixtures.
public export
runDecorativeTests : Bool
runDecorativeTests =
     all (\f => f testDecorated) decorativeTests
  && differentValuesNotEqual
  && emptyMetadataRejected

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
