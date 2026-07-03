-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Taxonomy

import public ProvenTests.Types
import ProvenTests.Classification

-- =============================================================================
-- TEST CATEGORY TAXONOMY
-- =============================================================================
-- TestCategory and TestAspect are defined in ProvenTests.Types (so that
-- TestMetadata can carry typed axes) and re-exported here via
-- `import public ProvenTests.Types`. The enumerations and provenance
-- mapping below remain the taxonomy utilities.

-- =============================================================================
-- TYPE-SAFE TESTING SUBCATEGORIES
-- =============================================================================

--/ Subcategories for Type-Safe testing
public export
data TypeSafeSubcategory : Type where
  TropicalTypeTest     : TypeSafeSubcategory
  EpistemicTypeTest    : TypeSafeSubcategory
  ChoreographicTypeTest : TypeSafeSubcategory
  DependentTypeTest    : TypeSafeSubcategory
  EffectsTypeTest     : TypeSafeSubcategory
  DecorativeTypeTest   : TypeSafeSubcategory
  CeremonialTypeTest   : TypeSafeSubcategory
  DyadicTypeTest      : TypeSafeSubcategory
  EchoTypesTest        : TypeSafeSubcategory

-- =============================================================================
-- KATEGORIA LEVELS (from TESTING-TAXONOMY.adoc Part III)
-- =============================================================================

--/ Kategoria Type Safety Levels L1-L12
public export
data KategoriaLevel : Type where
  L1 : KategoriaLevel  -- Basic Types
  L2 : KategoriaLevel  -- Algebraic Data Types
  L3 : KategoriaLevel  -- Parametric Polymorphism
  L4 : KategoriaLevel  -- Higher-Kinded Types
  L5 : KategoriaLevel  -- GADTs
  L6 : KategoriaLevel  -- Dependent Types
  L7 : KategoriaLevel  -- Linear/Affine Types
  L8 : KategoriaLevel  -- Refinement Types
  L9 : KategoriaLevel  -- Session Types
  L10 : KategoriaLevel -- Homotopy/Cubical Types
  L11 : KategoriaLevel -- Tropical Cost-Tracking
  L12 : KategoriaLevel -- Epistemic Safety

export
Show KategoriaLevel where
  show L1 = "L1"
  show L2 = "L2"
  show L3 = "L3"
  show L4 = "L4"
  show L5 = "L5"
  show L6 = "L6"
  show L7 = "L7"
  show L8 = "L8"
  show L9 = "L9"
  show L10 = "L10"
  show L11 = "L11"
  show L12 = "L12"

-- =============================================================================
-- TAXONOMY UTILITIES
-- =============================================================================

--/ Get all test categories
public export
allTestCategories : List TestCategory
allTestCategories = [
  UnitTest, PointToPoint, EndToEnd, BuildTest, ExecutionRuntime,
  ReflexiveTest, LifecycleTest, SmokeTest, PropertyBasedTest,
  MutationTest, FuzzTest, ContractInvariantTest, RegressionTest,
  ChaosResilienceTest, CompatibilityTest, ProofRegressionTest, TypeSafeTest
]

--/ Get all test aspects
public export
allTestAspects : List TestAspect
allTestAspects = [
  Dependability, Security, Usability, Interoperability, Safety,
  Performance, Functionality, Versability, Accessibility,
  Maintainability, Privacy, Observability, Reproducibility, Portability
]

--/ Get all Kategoria levels
public export
allKategoriaLevels : List KategoriaLevel
allKategoriaLevels = [L1, L2, L3, L4, L5, L6, L7, L8, L9, L10, L11, L12]

-- =============================================================================
-- CATEGORY MAPPING TO PROVENANCE
-- =============================================================================

--/ Map test category to typical provenance level
public export
categoryToTypicalProvenance : TestCategory -> ProvenStatus
categoryToTypicalProvenance cat = case cat of
  TypeSafeTest => ProvisionallyProven  -- Type-safe tests are at least Provisionally-Proven
  ProofRegressionTest => ActuallyProven  -- Proof regression tests verify proofs
  ContractInvariantTest => ProvisionallyProven  -- Contract tests use type-safe framework
  PropertyBasedTest => ProvisionallyProven  -- Property tests use QuickCheck/hspec
  _ => Unproven  -- Others start as Unproven
