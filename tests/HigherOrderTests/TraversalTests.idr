-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module HigherOrderTests.TraversalTests

import ProvenTests.HigherOrder.Traversal
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- TRAVERSAL LAW TESTS - EXECUTABLE
-- =============================================================================

private
traversalTestId : Nat -> TestId
traversalTestId n =
  MkTestId "ProvenTests.HigherOrder.TraversalTests" ("test_" ++ show n) n

public export
testPreservesLength : ProvisionallyProvenTest
testPreservesLength =
  provisionalTest (traversalTestId 1) "A traversal preserves length" (
    assertTrue (traversalPreservesLength length exampleWords)
      "Mapping over a list should not change its length"
  )

public export
testPreservesEmpty : ProvisionallyProvenTest
testPreservesEmpty =
  provisionalTest (traversalTestId 2) "A traversal preserves emptiness" (
    assertTrue (traversalPreservesEmpty length (the (List String) []))
      "Mapping over [] should yield []"
  )

public export
testFusion : ProvisionallyProvenTest
testFusion =
  provisionalTest (traversalTestId 3) "map g . map f = map (g . f)" (
    assertTrue (traversalFusionAt (\n => n * 2) (\n => n + 1) exampleLengths)
      "Two traversals should fuse into one"
  )

public export
testRespectsOrder : ProvisionallyProvenTest
testRespectsOrder =
  provisionalTest (traversalTestId 4) "map f . reverse = reverse . map f" (
    assertTrue (traversalRespectsOrder length exampleWords)
      "A traversal should commute with reverse"
  )

public export
testTraverseMaybeTotal : ProvisionallyProvenTest
testTraverseMaybeTotal =
  provisionalTest (traversalTestId 5) "traverse (Just . f) = Just . map f" (
    assertTrue (traverseMaybeTotal length exampleWords)
      "A never-failing effectful traversal should equal a pure map"
  )

public export
testTraverseShortCircuits : ProvisionallyProvenTest
testTraverseShortCircuits =
  provisionalTest (traversalTestId 6) "traverse short-circuits on Nothing" (
    assertTrue (traverseMaybeShortCircuits exampleWords)
      "One Nothing should make the whole traversal Nothing"
  )

public export
allTraversalTests : List ProvisionallyProvenTest
allTraversalTests = [
    testPreservesLength,
    testPreservesEmpty,
    testFusion,
    testRespectsOrder,
    testTraverseMaybeTotal,
    testTraverseShortCircuits
  ]
