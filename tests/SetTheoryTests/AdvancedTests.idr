-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module SetTheoryTests.AdvancedTests

import ProvenTests.SetTheory.Advanced
import ProvenTests.SetTheory.Basics
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- HIGHER SET CONCEPT TESTS - EXECUTABLE
-- =============================================================================

private
advancedTestId : Nat -> TestId
advancedTestId n =
  MkTestId "ProvenTests.SetTheory.AdvancedTests" ("test_" ++ show n) n

public export
testSubsetReflexive : ProvisionallyProvenTest
testSubsetReflexive =
  provisionalTest (advancedTestId 1) "Subset is reflexive" (
    assertTrue (subsetReflexive setA) "Every set is a subset of itself"
  )

public export
testSubsetTransitive : ProvisionallyProvenTest
testSubsetTransitive =
  provisionalTest (advancedTestId 2) "Subset is transitive" (
    assertTrue (subsetTransitive smallSet setA universe)
      "Subset should be transitive"
  )

public export
testSubsetAntisymmetric : ProvisionallyProvenTest
testSubsetAntisymmetric =
  provisionalTest (advancedTestId 3) "Mutual inclusion implies equality" (
    assertTrue (subsetAntisymmetric setA setA)
      "Antisymmetry should hold for the subset order"
  )

public export
testIntersectIsSubset : ProvisionallyProvenTest
testIntersectIsSubset =
  provisionalTest (advancedTestId 4) "A n B is a subset of A" (
    assertTrue (intersectIsSubset setA setB)
      "An intersection should be contained in each argument"
  )

public export
testUnionContains : ProvisionallyProvenTest
testUnionContains =
  provisionalTest (advancedTestId 5) "A is a subset of A u B" (
    assertTrue (unionContains setA setB)
      "Each argument should be contained in the union"
  )

public export
testEmptyIsSubset : ProvisionallyProvenTest
testEmptyIsSubset =
  provisionalTest (advancedTestId 6) "{} is a subset of everything" (
    assertTrue (emptyIsSubset setA)
      "The empty set should be a subset of any set"
  )

public export
testPowerSetCardinality : ProvisionallyProvenTest
testPowerSetCardinality =
  provisionalTest (advancedTestId 7) "|P(S)| = 2^|S|" (
    assertTrue (powerSetCardinality smallSet)
      "The power set should have exactly 2^n members"
  )

public export
testPowerSetMembersAreSubsets : ProvisionallyProvenTest
testPowerSetMembersAreSubsets =
  provisionalTest (advancedTestId 8) "Every member of P(S) is a subset of S" (
    assertTrue (powerSetMembersAreSubsets smallSet)
      "Power-set members should all be subsets"
  )

public export
testPowerSetExtremes : ProvisionallyProvenTest
testPowerSetExtremes =
  provisionalTest (advancedTestId 9) "P(S) contains {} and S" (
    assertTrue (powerSetContainsExtremes tinySet)
      "The power set should contain both extremes"
  )

public export
testInclusionExclusion : ProvisionallyProvenTest
testInclusionExclusion =
  provisionalTest (advancedTestId 10) "|A u B| + |A n B| = |A| + |B|" (
    assertTrue (inclusionExclusion setA setB)
      "Inclusion-exclusion should hold"
  )

public export
allAdvancedTests : List ProvisionallyProvenTest
allAdvancedTests = [
    testSubsetReflexive,
    testSubsetTransitive,
    testSubsetAntisymmetric,
    testIntersectIsSubset,
    testUnionContains,
    testEmptyIsSubset,
    testPowerSetCardinality,
    testPowerSetMembersAreSubsets,
    testPowerSetExtremes,
    testInclusionExclusion
  ]
