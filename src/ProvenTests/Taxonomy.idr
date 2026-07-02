-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Taxonomy

import ProvenTests.Types
import ProvenTests.Classification

-- =============================================================================
-- TEST CATEGORY TAXONOMY (from standards/testing-and-benchmarking/TESTING-TAXONOMY.adoc)
-- =============================================================================

--/ All test categories from the Hyperpolymath Testing Taxonomy
public export
data TestCategory : Type where
  UnitTest             : TestCategory
  PointToPoint         : TestCategory
  EndToEnd            : TestCategory
  BuildTest           : TestCategory
  ExecutionRuntime     : TestCategory
  ReflexiveTest       : TestCategory
  LifecycleTest       : TestCategory
  SmokeTest           : TestCategory
  PropertyBasedTest    : TestCategory
  MutationTest        : TestCategory
  FuzzTest            : TestCategory
  ContractInvariantTest : TestCategory
  RegressionTest      : TestCategory
  ChaosResilienceTest : TestCategory
  CompatibilityTest    : TestCategory
  ProofRegressionTest  : TestCategory
  TypeSafeTest        : TestCategory  -- NEW: Type-safe testing category

-- Display instance
export
Show TestCategory where
  show UnitTest = "Unit"
  show PointToPoint = "P2P"
  show EndToEnd = "E2E"
  show BuildTest = "Build"
  show ExecutionRuntime = "Execution"
  show ReflexiveTest = "Reflexive"
  show LifecycleTest = "Lifecycle"
  show SmokeTest = "Smoke"
  show PropertyBasedTest = "Property"
  show MutationTest = "Mutation"
  show FuzzTest = "Fuzz"
  show ContractInvariantTest = "Contract"
  show RegressionTest = "Regression"
  show ChaosResilienceTest = "Chaos"
  show CompatibilityTest = "Compatibility"
  show ProofRegressionTest = "Proof-Regression"
  show TypeSafeTest = "Type-Safe"

-- Equality on categories (distinct display names are injective)
public export
Eq TestCategory where
  a == b = show a == show b

-- =============================================================================
-- ASPECT DIMENSIONS (from TESTING-TAXONOMY.adoc Part II)
-- =============================================================================

--/ All 14 aspect dimensions from Hyperpolymath Testing Taxonomy
public export
data TestAspect : Type where
  Dependability    : TestAspect
  Security         : TestAspect
  Usability        : TestAspect
  Interoperability : TestAspect
  Safety           : TestAspect
  Performance      : TestAspect
  Functionality    : TestAspect
  Versability      : TestAspect
  Accessibility    : TestAspect
  Maintainability  : TestAspect
  Privacy          : TestAspect
  Observability    : TestAspect
  Reproducibility  : TestAspect
  Portability      : TestAspect

-- Display instance
export
Show TestAspect where
  show Dependability = "Dependability"
  show Security = "Security"
  show Usability = "Usability"
  show Interoperability = "Interoperability"
  show Safety = "Safety"
  show Performance = "Performance"
  show Functionality = "Functionality"
  show Versability = "Versability"
  show Accessibility = "Accessibility"
  show Maintainability = "Maintainability"
  show Privacy = "Privacy"
  show Observability = "Observability"
  show Reproducibility = "Reproducibility"
  show Portability = "Portability"

-- Equality on aspects (distinct display names are injective)
public export
Eq TestAspect where
  a == b = show a == show b

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
