-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module TypeSafeTests.EffectsTests

import ProvenTests.TypeSafe.Effects
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- EFFECTS TYPE TESTS - EXECUTABLE TESTS
-- =============================================================================


-- Helper: Create test ID for effects tests
private
effectsTestId : Nat -> TestId
effectsTestId n = MkTestId "ProvenTests.TypeSafe.EffectsTests" ("test_" ++ show n) n

-- Test: Pure effect has no side effects
public export
testEffectPureIsPure : ProvisionallyProvenTest
testEffectPureIsPure = 
  provisionalTest (effectsTestId 1) "Pure effect has no side effects" (
    assertTrue (effectPureIsPure Pure) 
      "Pure effect should have no side effects"
  )

-- Test: Effect stack is valid
public export
testEffectStackValid : ProvisionallyProvenTest
testEffectStackValid = 
  provisionalTest (effectsTestId 2) "Effect stack is valid" (
    assertTrue (effectStackValid stateStack) 
      "State effect stack should be valid"
  )

-- Test: State effect implies Read and Write
public export
testEffectStateImpliesReadWrite : ProvisionallyProvenTest
testEffectStateImpliesReadWrite = 
  provisionalTest (effectsTestId 3) "State effect implies Read and Write" (
    assertTrue (effectStateImpliesReadWrite stateStack) 
      "State effect should require both Read and Write"
  )

-- Test: Effect order matters for State
public export
testEffectOrderMatters : ProvisionallyProvenTest
testEffectOrderMatters = 
  provisionalTest (effectsTestId 4) "Effect order matters for State" (
    assertTrue (effectOrderMatters stateStack) 
      "Effect order should matter for State"
  )

-- Test: All effects tests pass
public export
testEffectsAllTestsPass : ProvisionallyProvenTest
testEffectsAllTestsPass = 
  provisionalTest (effectsTestId 5) "All effects tests pass" (
    assertTrue (runEffectsTests) 
      "All effects type tests should pass"
  )

-- All effects tests
public export
allEffectsTests : List (ProvisionallyProvenTest)
allEffectsTests = [
    testEffectPureIsPure,
    testEffectStackValid,
    testEffectStateImpliesReadWrite,
    testEffectOrderMatters,
    testEffectsAllTestsPass
  ]
