-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Taxonomy

import public ProvenTests.Types
import ProvenTests.Classification
import Data.List.Elem

%default total

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
-- EXHAUSTIVENESS OBLIGATIONS (Category 18 / plan WS3 commit A)
-- =============================================================================
-- `allTestCategories` is a LIST LITERAL, and a list literal is total no matter
-- what it omits. It is the one site the compiler cannot see: measured on
-- 414b00a, appending a constructor to `TestCategory` and giving it the `Show`
-- clause the coverage checker demands leaves `idris2 --build` GREEN, every
-- suite passing, and `check-doc-facts.sh source` reporting "categories = 17".
-- The enum and the list can therefore disagree with nothing turning red.
--
-- These four obligations close that hole at COMPILE TIME:
--   * a constructor missing from the list has no `Elem` proof   -> type error
--   * a constructor added to the enum makes the function non-covering
--   * the length proofs pin the cardinality the published figures rest on
-- Adding Category 18 therefore cannot be done half-way; see commit B.

--/ Every `TestCategory` constructor appears in `allTestCategories`.
public export
allTestCategoriesComplete : (c : TestCategory) -> Elem c Taxonomy.allTestCategories
allTestCategoriesComplete UnitTest              = Here
allTestCategoriesComplete PointToPoint          = There Here
allTestCategoriesComplete EndToEnd              = There (There Here)
allTestCategoriesComplete BuildTest             = There (There (There Here))
allTestCategoriesComplete ExecutionRuntime      = There (There (There (There Here)))
allTestCategoriesComplete ReflexiveTest         = There (There (There (There (There Here))))
allTestCategoriesComplete LifecycleTest         = There (There (There (There (There (There Here)))))
allTestCategoriesComplete SmokeTest             = There (There (There (There (There (There (There Here))))))
allTestCategoriesComplete PropertyBasedTest     = There (There (There (There (There (There (There (There Here)))))))
allTestCategoriesComplete MutationTest          = There (There (There (There (There (There (There (There (There Here))))))))
allTestCategoriesComplete FuzzTest              = There (There (There (There (There (There (There (There (There (There Here)))))))))
allTestCategoriesComplete ContractInvariantTest = There (There (There (There (There (There (There (There (There (There (There Here))))))))))
allTestCategoriesComplete RegressionTest        = There (There (There (There (There (There (There (There (There (There (There (There Here)))))))))))
allTestCategoriesComplete ChaosResilienceTest   = There (There (There (There (There (There (There (There (There (There (There (There (There Here))))))))))))
allTestCategoriesComplete CompatibilityTest     = There (There (There (There (There (There (There (There (There (There (There (There (There (There Here)))))))))))))
allTestCategoriesComplete ProofRegressionTest   = There (There (There (There (There (There (There (There (There (There (There (There (There (There (There Here))))))))))))))
allTestCategoriesComplete TypeSafeTest          = There (There (There (There (There (There (There (There (There (There (There (There (There (There (There (There Here)))))))))))))))

--/ The category cardinality the lattice arithmetic depends on.
public export
categoryCount : length Taxonomy.allTestCategories = 17
categoryCount = Refl

--/ Every `TestAspect` constructor appears in `allTestAspects`.
public export
allTestAspectsComplete : (a : TestAspect) -> Elem a Taxonomy.allTestAspects
allTestAspectsComplete Dependability    = Here
allTestAspectsComplete Security         = There Here
allTestAspectsComplete Usability        = There (There Here)
allTestAspectsComplete Interoperability = There (There (There Here))
allTestAspectsComplete Safety           = There (There (There (There Here)))
allTestAspectsComplete Performance      = There (There (There (There (There Here))))
allTestAspectsComplete Functionality    = There (There (There (There (There (There Here)))))
allTestAspectsComplete Versability      = There (There (There (There (There (There (There Here))))))
allTestAspectsComplete Accessibility    = There (There (There (There (There (There (There (There Here)))))))
allTestAspectsComplete Maintainability  = There (There (There (There (There (There (There (There (There Here))))))))
allTestAspectsComplete Privacy          = There (There (There (There (There (There (There (There (There (There Here)))))))))
allTestAspectsComplete Observability    = There (There (There (There (There (There (There (There (There (There (There Here))))))))))
allTestAspectsComplete Reproducibility  = There (There (There (There (There (There (There (There (There (There (There (There Here)))))))))))
allTestAspectsComplete Portability      = There (There (There (There (There (There (There (There (There (There (There (There (There Here))))))))))))

--/ The aspect cardinality the lattice arithmetic depends on.
public export
aspectCount : length Taxonomy.allTestAspects = 14
aspectCount = Refl

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
