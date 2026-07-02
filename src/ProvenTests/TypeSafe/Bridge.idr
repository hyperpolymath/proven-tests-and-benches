-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.TypeSafe.Bridge

import ProvenTests.Types
import ProvenTests.Classification
import Data.String
import ProvenTests.TypeSafe.Tropical
import ProvenTests.TypeSafe.Epistemic
import ProvenTests.TypeSafe.Choreographic
import ProvenTests.TypeSafe.Dependent
import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Decorative
import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.TypeSafe.Dyadic

-- =============================================================================
-- ECHO-TYPES INTEGRATION BRIDGE (STAND-IN)
-- =============================================================================
-- HONESTY NOTE: this module is a stand-in contract, not a live integration.
-- There is no dependency on the echo-types repository: `EchoTypesBridge` is a
-- hardcoded record and the "bridge" checks below are structural (list length,
-- URL prefix, version string). They pin down the intended contract shape so a
-- future real integration has something to satisfy, and they are graded
-- accordingly — nothing in this module claims more than Provisionally-Proven.


-- Bridge configuration
public export
record EchoTypesBridge where
  constructor MkEchoTypesBridge
  echo_types_repo : String
  integration_version : String
  supported_categories : List TypeSafeCategory

-- Default bridge configuration
public export
defaultEchoTypesBridge : EchoTypesBridge
defaultEchoTypesBridge = MkEchoTypesBridge
  "https://github.com/hyperpolymath/echo-types"
  "1.0.0"
  [Tropical, Epistemic, Choreographic, Dependent, Effects, Decorative, Ceremonial, Dyadic, EchoTypes]

-- Test: Bridge connects to all categories
public export
bridgeConnectsToAllCategories : EchoTypesBridge -> Bool
bridgeConnectsToAllCategories (MkEchoTypesBridge _ _ cats) = 
  length cats == 9  -- All 9 categories supported

-- Test: Bridge version is valid
public export
bridgeVersionValid : EchoTypesBridge -> Bool
bridgeVersionValid (MkEchoTypesBridge _ v _) = 
  v /= "" && v /= "0.0.0" && v /= "unknown"

-- Test: Bridge repository is accessible
public export
bridgeRepoAccessible : EchoTypesBridge -> Bool
bridgeRepoAccessible (MkEchoTypesBridge repo _ _) =
  isPrefixOf "https://github.com/" repo

-- Test: Bridge supports echo-types category
public export
bridgeSupportsEchoTypes : EchoTypesBridge -> Bool
bridgeSupportsEchoTypes (MkEchoTypesBridge _ _ cats) = 
  EchoTypes `elem` cats

-- Integration test: Run all type-safe tests through bridge
public export
runAllTypeSafeTests : Bool
runAllTypeSafeTests = 
  runTropicalTests &&
  runEpistemicTests &&
  runChoreographicTests &&
  runDependentTests &&
  runEffectsTests &&
  runDecorativeTests &&
  runCeremonialTests &&
  runDyadicTests

-- Bridge test suite
public export
bridgeTestSuite : List (EchoTypesBridge -> Bool)
bridgeTestSuite = [
    bridgeConnectsToAllCategories,
    bridgeVersionValid,
    bridgeRepoAccessible,
    bridgeSupportsEchoTypes,
    (\_ => runAllTypeSafeTests)
  ]

-- Run bridge tests
public export
allBridgeTestsPass : Bool
allBridgeTestsPass = all (\f => f defaultEchoTypesBridge) bridgeTestSuite

-- =============================================================================
-- ECHO-TYPES SPECIFIC TESTS
-- =============================================================================

-- Echo type representation (simplified)
public export
data Echo : Type -> Type where
  MkEcho : a -> Echo a

-- Test: Echo preserves type
public export
echoPreservesType : Echo Nat -> Bool
echoPreservesType (MkEcho _) = True

-- Test: Echo can be unwrapped
public export
echoUnwrappable : Echo Nat -> Nat
echoUnwrappable (MkEcho x) = x

-- Echo type properties
public export
runEchoTypeTests : Bool
runEchoTypeTests = 
  echoPreservesType (MkEcho 42) &&
  echoUnwrappable (MkEcho 42) == 42

-- =============================================================================
-- INTEGRATION WITH PROVEN TESTS FRAMEWORK
-- =============================================================================

public export
bridgeClassification : TestMetadata
bridgeClassification = 
  let tid = MkTestId "ProvenTests.TypeSafe.Bridge" "allTests" 0
      desc = "Echo-types integration bridge tests"
      framework = provenTestsFrameworkProof
      cert = typeSafetyCert 6 "Echo-Types Bridge" "Idris2 + echo-types" ["Integration"]
  in classifyProvisionallyProven tid desc framework cert
