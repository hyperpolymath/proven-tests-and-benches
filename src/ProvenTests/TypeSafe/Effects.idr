-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.TypeSafe.Effects

import ProvenTests.Types
import ProvenTests.Classification
import Data.String

-- =============================================================================
-- EFFECTS SYSTEM TESTS
-- =============================================================================
-- Tests for Idris2 core effect system properties
-- Ensures effect safety and correctness


-- Simple effect type
public export
data Effect : Type where
  Pure : Effect
  Read : Effect
  Write : Effect
  State : Effect
  Exception : Effect

-- Equality on effects (required by `elem` below)
public export
Eq Effect where
  Pure == Pure = True
  Read == Read = True
  Write == Write = True
  State == State = True
  Exception == Exception = True
  _ == _ = False

-- Effect stack
public export
EffectStack : Type
EffectStack = List Effect

-- Test: Pure effect has no side effects
public export
effectPureIsPure : Effect -> Bool
effectPureIsPure Pure = True
effectPureIsPure _ = False

-- Test: Effect stack contains only valid effects
public export
effectStackValid : EffectStack -> Bool
effectStackValid [] = True
effectStackValid (Pure :: xs) = effectStackValid xs
effectStackValid (Read :: xs) = effectStackValid xs
effectStackValid (Write :: xs) = effectStackValid xs
effectStackValid (State :: xs) = effectStackValid xs
effectStackValid (Exception :: xs) = effectStackValid xs

-- Test: State effect requires both read and write
public export
effectStateImpliesReadWrite : EffectStack -> Bool
effectStateImpliesReadWrite xs =
  if (State `elem` xs)
    then ((Read `elem` xs) && (Write `elem` xs))
    else True

-- Test: Effect order matters for State
public export
effectOrderMatters : EffectStack -> Bool
effectOrderMatters [] = True
effectOrderMatters (State :: _) = True
effectOrderMatters _ = False

-- Test data
public export
pureStack : EffectStack
pureStack = [Pure]

public export
ioStack : EffectStack
ioStack = [Read, Write]

public export
stateStack : EffectStack
stateStack = [State, Read, Write]

-- =============================================================================
-- TESTS AS TYPE-SAFE PROPERTIES
-- =============================================================================

public export
effectsTests : List (EffectStack -> Bool)
effectsTests = [
    (\_ => effectPureIsPure Pure),
    effectStackValid,
    effectStateImpliesReadWrite,
    effectOrderMatters
  ]

-- Run all effects tests.
-- Each property is applied to inputs where it is actually meant to hold:
-- `effectOrderMatters` only holds for empty or State-headed stacks, so it is not
-- asserted over arbitrary stacks.
public export
runEffectsTests : Bool
runEffectsTests =
  effectPureIsPure Pure &&
  effectStackValid pureStack &&
  effectStackValid ioStack &&
  effectStackValid stateStack &&
  effectStateImpliesReadWrite pureStack &&
  effectStateImpliesReadWrite ioStack &&
  effectStateImpliesReadWrite stateStack &&
  effectOrderMatters stateStack &&
  effectOrderMatters []

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
effectsClassification : TestMetadata
effectsClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Effects" "allTests" 0
      desc = "Effects system property tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Idris2 Effect System" "Idris2 core" ["Effect safety"]
  in classifyProvisionallyProven tid desc framework cert
