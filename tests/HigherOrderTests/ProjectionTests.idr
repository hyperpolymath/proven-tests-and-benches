-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module HigherOrderTests.ProjectionTests

import ProvenTests.HigherOrder.Projection
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- PROJECTION / LENS LAW TESTS - EXECUTABLE
-- =============================================================================

private
projectionTestId : Nat -> TestId
projectionTestId n =
  MkTestId "ProvenTests.HigherOrder.ProjectionTests" ("test_" ++ show n) n

public export
testGetPut : ProvisionallyProvenTest
testGetPut =
  provisionalTest (projectionTestId 1) "get-put: put (get s) s = s" (
    assertTrue (getPutAt xLens examplePoint)
      "Putting back what you got should leave the structure unchanged"
  )

public export
testPutGet : ProvisionallyProvenTest
testPutGet =
  provisionalTest (projectionTestId 2) "put-get: get (put a s) = a" (
    assertTrue (putGetAt xLens 99 examplePoint)
      "Getting what you just put should return it"
  )

public export
testPutPut : ProvisionallyProvenTest
testPutPut =
  provisionalTest (projectionTestId 3) "put-put: the last put wins" (
    assertTrue (putPutAt xLens 1 2 examplePoint)
      "Two puts in sequence should equal the second alone"
  )

public export
testAllLensLaws : ProvisionallyProvenTest
testAllLensLaws =
  provisionalTest (projectionTestId 4) "All three lens laws hold together" (
    assertTrue (lensLawsAt xLens 11 22 examplePoint)
      "xLens should be a lawful lens"
  )

public export
testProjectionIdempotent : ProvisionallyProvenTest
testProjectionIdempotent =
  provisionalTest (projectionTestId 5) "p . p = p" (
    assertTrue (projectionIdempotentAt ontoXAxis examplePoint)
      "Projecting onto the x-axis twice should equal projecting once"
  )

public export
allProjectionTests : List ProvisionallyProvenTest
allProjectionTests = [
    testGetPut,
    testPutGet,
    testPutPut,
    testAllLensLaws,
    testProjectionIdempotent
  ]
