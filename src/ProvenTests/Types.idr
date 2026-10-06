-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Types

-- Core types for the Proven-Tests framework

import Data.String
import Data.List
import Data.List1
import Data.Maybe
import public Language.Reflection

%language ElabReflection
%default total

-- =============================================================================
-- PROVENANCE CLASSIFICATION
-- =============================================================================

--/ Three-tier provenance classification for tests
public export
data ProvenStatus : Type where
  ActuallyProven : ProvenStatus
  ProvisionallyProven : ProvenStatus
  Unproven : ProvenStatus

-- Display instance for ProvenStatus
export
Show ProvenStatus where
  show ActuallyProven = "Actually-Proven"
  show ProvisionallyProven = "Provisionally-Proven"
  show Unproven = "Unproven"

-- Equality on the bare status tag
export
Eq ProvenStatus where
  ActuallyProven == ActuallyProven = True
  ProvisionallyProven == ProvisionallyProven = True
  Unproven == Unproven = True
  _ == _ = False

-- =============================================================================
-- PROOF STEPS
-- =============================================================================

--/ A step in a proof ladder
public export
record ProofStep where
  constructor MkProofStep
  description : String
  proof_file   : Maybe String
  line_number  : Maybe Nat
  theorem     : Maybe String

-- =============================================================================
-- DESIGN PROOFS
-- =============================================================================

--/ Proof that the general design is safe
public export
record DesignSafetyProof where
  constructor MkDesignSafetyProof
  description      : String
  proof_technique  : String
  coverage         : List String
  limitations      : List String

-- =============================================================================
-- TYPE SAFETY CERTIFICATES
-- =============================================================================

--/ Certificate of type safety for a framework or component
public export
record TypeSafetyCertificate where
  constructor MkTypeSafetyCertificate
  kategoria_level : Nat
  type_system     : String
  verified_by     : String
  scope          : List String

-- =============================================================================
-- FRAMEWORK SAFETY
-- =============================================================================

--/ Proof that a framework is type-safe
public export
record FrameworkSafetyProof where
  constructor MkFrameworkSafetyProof
  framework_name : String
  type_safety    : TypeSafetyCertificate
  test_safety    : TypeSafetyCertificate
  documentation : String

-- =============================================================================
-- TEST IDENTIFICATION
-- =============================================================================

--/ Unique identifier for a test
public export
record TestId where
  constructor MkTestId
  module_path : String
  test_name   : String
  line_number : Nat

-- Display instance
export
Show TestId where
  show (MkTestId mp tn ln) = mp ++ "." ++ tn ++ " (line " ++ show ln ++ ")"

-- =============================================================================
-- TEST RESULTS
-- =============================================================================

--/ Result of running a test
public export
data TestResult : Type where
  Passed : TestResult
  Failed : String -> TestResult
  Error  : String -> TestResult
  Skipped : String -> TestResult

-- Display instance
export
Show TestResult where
  show Passed = "PASSED"
  show (Failed msg) = "FAILED: " ++ msg
  show (Error msg) = "ERROR: " ++ msg
  show (Skipped reason) = "SKIPPED: " ++ reason

-- =============================================================================
-- TYPE-SAFE TESTING CATEGORIES
-- =============================================================================

--/ Categories for type-safe testing
public export
data TypeSafeCategory : Type where
  Tropical     : TypeSafeCategory
  Epistemic    : TypeSafeCategory
  Choreographic : TypeSafeCategory
  Dependent    : TypeSafeCategory
  Effects      : TypeSafeCategory
  Decorative   : TypeSafeCategory
  Ceremonial   : TypeSafeCategory
  Dyadic       : TypeSafeCategory
  EchoTypes    : TypeSafeCategory

-- Display instance
export
Show TypeSafeCategory where
  show Tropical = "Tropical"
  show Epistemic = "Epistemic"
  show Choreographic = "Choreographic"
  show Dependent = "Dependent"
  show Effects = "Effects"
  show Decorative = "Decorative"
  show Ceremonial = "Ceremonial"
  show Dyadic = "Dyadic"
  show EchoTypes = "Echo-Types"

-- Equality on type-safe categories (distinct display names are injective)
export
Eq TypeSafeCategory where
  x == y = show x == show y

-- =============================================================================
-- TEST TAXONOMY AXES
-- =============================================================================
-- TestCategory and TestAspect live here (rather than in ProvenTests.Taxonomy,
-- which re-exports them) so that TestMetadata below can carry *typed* axes
-- without an import cycle. The taxonomy source of truth is
-- standards/3-practice/testing-and-benchmarking/TESTING-TAXONOMY.adoc.

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
  TypeSafeTest        : TestCategory

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

--/ All 14 aspect dimensions from the Hyperpolymath Testing Taxonomy
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
-- TEST METADATA
-- =============================================================================

-- =============================================================================
-- EVIDENCE-CARRYING PROVENANCE
-- =============================================================================
-- A test's provenance is inseparable from the evidence that justifies it: the
-- data constructors below *require* that evidence as typed fields, so a test
-- cannot be labelled Provisionally- or Actually-Proven without supplying it.

--/ Evidence required to justify a Provisionally-Proven classification
public export
record ProvisionalEvidence where
  constructor MkProvisionalEvidence
  framework_safety : FrameworkSafetyProof
  test_safety      : TypeSafetyCertificate

--/ One rung of an Actually-Proven ladder: the citation AND the proof term it
--/ cites. `statement` is the proposition; `term` must inhabit it, so the
--/ typechecker — not a reviewer — confirms the cited theorem exists, still has
--/ the stated type, and is the term the ladder names. Both are erased (quantity
--/ 0): the evidence is checked at compile time and costs nothing at run time.
--/
--/ What this does NOT stop: a deliberately trivial witness
--/ (`Witness s () ()`) still compiles. That forgery is now a visible lie in
--/ code rather than an unchecked string, and `tests/SpecSuite/Main.idr` keeps
--/ it as a recorded positive control so nobody reads the tier as unforgeable.
public export
record Witnessed where
  constructor Witness
  step          : ProofStep
  0 statement   : Type
  0 term        : statement

-- =============================================================================
-- RUNG: a proof-carrying ladder step whose citation cannot drift from its term
-- =============================================================================
-- Built with the `Witness` constructor directly, a rung's `theorem` string and
-- its proof term are two independent inputs: `Just "noSuchTheorem"` beside
-- `oplusComm` typechecks, and the report would publish the dangling citation.
--
-- `rung` takes ONE input for both, a quoted name (`{oplusComm}). At compile
-- time it elaborates that name against the stated proposition and derives the
-- citation from the same name, so the name that is checked is the name that is
-- printed. A missing theorem is "Undefined name"; a theorem that proves a
-- different proposition fails to unify. tests/SpecSuite/Main.idr holds both as
-- `failing` blocks, plus a compile-time check that the derived citation is the
-- literal name.
--
-- Every ladder in this repository is built with `rung`. The constructor stays
-- public (other modules pattern-match on it), so a hand-built `Witness` with a
-- mismatched label still compiles; SpecSuite keeps that as a residual control.

--/ The unqualified name of a quoted theorem: `ProvenTests.Tropical.oplusComm`
--/ and `oplusComm` both give "oplusComm". Public so the derived citation
--/ reduces at compile time.
public export
baseName : Name -> String
baseName (NS _ n) = baseName n
baseName (UN (Basic s)) = s
baseName n = show n

--/ A proof-carrying rung: description, cited file, optional line, the quoted
--/ theorem name, and the full proposition it proves. The term is the theorem
--/ itself, checked against the proposition; the citation is derived from it.
export
%macro
rung : String -> Maybe String -> Maybe Nat -> Name -> (stmt : Type) -> Elab Witnessed
rung desc file line thm stmt = do
  prf <- check {expected = stmt} (IVar EmptyFC thm)
  pure (Witness (MkProofStep desc file line (Just (baseName thm))) stmt prf)

--/ Evidence required to justify an Actually-Proven classification.
--/ The proof ladder is a non-empty `List1` of proof-carrying rungs, so it is
--/ impossible to claim Actually-Proven with zero proof steps, and every step
--/ carries a typechecked proof term (see `Witnessed`).
public export
record ActualEvidence where
  constructor MkActualEvidence
  proof_ladder : List1 Witnessed
  design_proof : DesignSafetyProof
  type_safety  : TypeSafetyCertificate

--/ Provenance carries its own justification as a typed payload
public export
data Provenance : Type where
  PUnproven            : Provenance
  PProvisionallyProven : ProvisionalEvidence -> Provenance
  PActuallyProven      : ActualEvidence -> Provenance

--/ Project the bare status tag (for display, comparison, reporting)
public export
statusOf : Provenance -> ProvenStatus
statusOf PUnproven                = Unproven
statusOf (PProvisionallyProven _) = ProvisionallyProven
statusOf (PActuallyProven _)      = ActuallyProven

export
Show Provenance where
  show = show . statusOf

-- =============================================================================
-- FIXTURE OBLIGATION (TEST-DOCTRINE.adoc §2; standards R10)
-- =============================================================================
-- The doctrine: every test ships a silence fixture (clean input, must NOT
-- fire — a fire is a harness fault) and a firing fixture (a committed
-- specimen of the declared defect class, MUST fire — silence is a payload
-- fault). "A test missing either fixture is *inadmissible*." This block makes
-- that a type obligation rather than a review convention, following the
-- `List1 Witnessed` precedent that makes zero-step (and proof-free)
-- Actually-Proven unrepresentable.

--/ Where a fixture lives. Runtime construction is legitimate (R10.7): a
--/ fixture built by the test run itself cannot silently rot into validity
--/ the way a committed file can.
public export
data FixtureSource : Type where
  OnDisk             : (path : String) -> FixtureSource
  RuntimeConstructed : (how : String) -> FixtureSource

--/ Clean input containing no member of the declared defect class (R10.6).
--/ The description says *why* it is clean — an undocumented silence fixture
--/ cannot be audited for accidental defect members.
public export
record SilenceFixture where
  constructor MkSilenceFixture
  source      : FixtureSource
  description : String

--/ A committed specimen of the declared defect class (R10.2) — the canonical
--/ wrongness. `defect_class` names the class member it presents, so the
--/ meta-check knows what "the specific thing" is.
public export
record FiringFixture where
  constructor MkFiringFixture
  source       : FixtureSource
  defect_class : String

--/ The pair the doctrine demands. CI runs both: silence must not fire,
--/ firing must fire, and a crash in either is exit 2 (NO CHECK PERFORMED),
--/ never a pass.
public export
record FixturePair where
  constructor MkFixturePair
  silence : SilenceFixture
  firing  : FiringFixture

--/ Every test states its fixture position — there is no silent default, which
--/ is the point: an optional field would be the type-level form of a gate
--/ that cannot fail.
--/
--/ * `Fixtures` — the doctrine's pair; the test is admissible and countable.
--/ * `CannotFailByDesign` — the R10.5 annotation: the checked property is
--/   enforced at compile time, so no runtime firing fixture can exist. The
--/   reason is mandatory and censused.
--/ * `FixtureDebt` — an explicit, dated admission that the pair is missing.
--/   Debt-marked tests are NOT counted as tests in any ledger (B.4: "any
--/   check with neither a firing fixture nor this annotation is not counted").
--/   This register may only shrink; new corpus units may never use it.
public export
data FixtureObligation : Type where
  Fixtures           : FixturePair -> FixtureObligation
  CannotFailByDesign : (reason : String) -> FixtureObligation
  FixtureDebt        : (debt_ref : String) -> FixtureObligation

--/ Metadata about a test. The category/aspect axes are *typed* — a metadata
--/ record can only claim a coordinate that exists in the taxonomy.
--/ `fixtures` is non-optional: a test cannot be constructed without stating
--/ its fixture position (TEST-DOCTRINE.adoc §2).
public export
record TestMetadata where
  constructor MkTestMetadata
  test_id      : TestId
  description   : String
  category      : Maybe TestCategory
  aspect        : Maybe TestAspect
  typesafe_cat  : Maybe TypeSafeCategory
  fixtures      : FixtureObligation
  provenance    : Provenance
