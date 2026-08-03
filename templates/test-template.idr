-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--
-- TEMPLATE — copy to tests/<Area>Tests/<Name>Tests.idr and edit.
-- Required by the Proven Tests spec §3.1. Not part of any ipkg: it is a file to
-- copy, not a module to build.
--
-- The shape below is the one every existing suite follows. Keeping to it is
-- what lets Main.idr aggregate suites by `++` without special cases.

module Area.NameTests   -- rename: must match the file path

import ProvenTests.Area.Name   -- the module under test
import ProvenTests.Framework
import ProvenTests.Types

-- =============================================================================
-- <NAME> TESTS - EXECUTABLE
-- =============================================================================

-- Test IDs are namespaced by module so two suites can both have a `test_1`
-- without colliding in the report.
private
nameTestId : Nat -> TestId
nameTestId n = MkTestId "ProvenTests.Area.NameTests" ("test_" ++ show n) n

-- --- One test per property ---------------------------------------------------
--
-- Use `provisionalTest` when the body is a Bool checked on concrete witnesses.
-- That is the honest tier for a run-time check and it is what almost everything
-- here is. See PROOFS.adoc for why the distinction is load-bearing.

public export
testSomeProperty : ProvisionallyProvenTest
testSomeProperty =
  provisionalTest (nameTestId 1) "Short statement of the property" (
    assertTrue (somePropertyAt exampleWitness)
      "What a reader should conclude if this fails"
  )

-- Use `assertEq` where an equality reads better than a Bool:
--
--   provisionalTest (nameTestId 2) "f is involutive" (
--     assertEq (f (f x)) x "f applied twice should return the original"
--   )

-- --- Promoting to Actually-Proven --------------------------------------------
--
-- Only when the property is quantified over ALL inputs and you have a term
-- inhabiting it. `provenTest` takes a `List1 ProofStep` ladder:
--
--   public export
--   testSomePropertyProven : ActuallyProvenTest
--   testSomePropertyProven =
--     provenTest (nameTestId 3) "Property holds for all inputs"
--       (assertTrue True "witness discharged by the proof below")
--       (singleton (MkProofStep ...))
--
-- Do NOT reach for this to make output look stronger. An ActuallyProven test
-- whose ladder does not actually establish the property is the one failure mode
-- this framework exists to prevent.

-- --- Export the list ----------------------------------------------------------
-- Main.idr concatenates these, so the name must be `all<Name>Tests`.

public export
allNameTests : List ProvisionallyProvenTest
allNameTests = [
    testSomeProperty
  ]
