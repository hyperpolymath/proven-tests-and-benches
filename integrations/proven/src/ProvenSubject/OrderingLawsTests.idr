-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.OrderingLawsTests

import Proven.SafeOrdering
import ProvenSubject.OrderingLaws
import ProvenTests.Framework
import ProvenTests.Types
import Data.List1
import Data.Vect

%default total

-- =============================================================================
-- proven's vector-clock laws as Actually-Proven tests
-- =============================================================================
-- The first Actually-Proven tests in this repository whose subject is code
-- shipped by another estate repository: `mergeVT`, `zeroVT` and `tickVT` are
-- proven's definitions (Proven.SafeOrdering at integrations/proven/PROVEN_PIN),
-- and each rung states its law about them in full. As in
-- tests/ProvenLawsTests/TropicalLawsTests.idr, one quoted name supplies both
-- the proof term and the printed citation, so a deleted, renamed or weakened
-- theorem stops this file compiling.

||| The TestId of the n-th proven ordering-law test.
private
orderingLawsTestId : Nat -> TestId
orderingLawsTestId n =
  MkTestId "ProvenSubject.OrderingLawsTests" ("test_" ++ show n) n

||| The file every rung in this module cites.
private
lawsFile : Maybe String
lawsFile = Just "integrations/proven/src/ProvenSubject/OrderingLaws.idr"

||| Runtime body of a law test: the law was discharged at compile time by the
||| rung, so this only records which theorem did it.
private
discharged : String -> IO TestResult
discharged thm =
  assertTrue True ("discharged at compile time by " ++ thm ++ " in OrderingLaws.idr")

||| mergeVT is commutative (theorem `mergeVTComm`).
public export
testMergeVTComm : ActuallyProvenTest
testMergeVTComm =
  provenTest (orderingLawsTestId 1)
    "proven mergeVT: commutative"
    (discharged "mergeVTComm")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTComm}
                     ({n : Nat} -> (a, b : VectorTimestamp n) -> mergeVT a b = mergeVT b a)))

||| mergeVT is associative (theorem `mergeVTAssoc`).
public export
testMergeVTAssoc : ActuallyProvenTest
testMergeVTAssoc =
  provenTest (orderingLawsTestId 2)
    "proven mergeVT: associative"
    (discharged "mergeVTAssoc")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTAssoc}
                     ({n : Nat} -> (a, b, c : VectorTimestamp n) ->
                      mergeVT a (mergeVT b c) = mergeVT (mergeVT a b) c)))

||| mergeVT is idempotent (theorem `mergeVTIdem`).
public export
testMergeVTIdem : ActuallyProvenTest
testMergeVTIdem =
  provenTest (orderingLawsTestId 3)
    "proven mergeVT: idempotent"
    (discharged "mergeVTIdem")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTIdem}
                     ({n : Nat} -> (a : VectorTimestamp n) -> mergeVT a a = a)))

||| zeroVT is a left identity of mergeVT (theorem `mergeVTZeroL`).
public export
testMergeVTZeroL : ActuallyProvenTest
testMergeVTZeroL =
  provenTest (orderingLawsTestId 4)
    "proven mergeVT: zeroVT is a left identity"
    (discharged "mergeVTZeroL")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTZeroL}
                     ({n : Nat} -> (a : VectorTimestamp n) ->
                      mergeVT Proven.SafeOrdering.zeroVT a = a)))

||| zeroVT is a right identity of mergeVT (theorem `mergeVTZeroR`).
public export
testMergeVTZeroR : ActuallyProvenTest
testMergeVTZeroR =
  provenTest (orderingLawsTestId 5)
    "proven mergeVT: zeroVT is a right identity"
    (discharged "mergeVTZeroR")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTZeroR}
                     ({n : Nat} -> (a : VectorTimestamp n) ->
                      mergeVT a Proven.SafeOrdering.zeroVT = a)))

||| mergeVT never moves the left input's entries backwards (theorem `mergeVTUpperL`).
public export
testMergeVTUpperL : ActuallyProvenTest
testMergeVTUpperL =
  provenTest (orderingLawsTestId 6)
    "proven mergeVT: dominates its left input at every process"
    (discharged "mergeVTUpperL")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTUpperL}
                     ({n : Nat} -> (i : Fin n) -> (a, b : VectorTimestamp n) ->
                      LTE (index i (vtValues a)) (index i (vtValues (mergeVT a b))))))

||| mergeVT never moves the right input's entries backwards (theorem `mergeVTUpperR`).
public export
testMergeVTUpperR : ActuallyProvenTest
testMergeVTUpperR =
  provenTest (orderingLawsTestId 7)
    "proven mergeVT: dominates its right input at every process"
    (discharged "mergeVTUpperR")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{mergeVTUpperR}
                     ({n : Nat} -> (i : Fin n) -> (a, b : VectorTimestamp n) ->
                      LTE (index i (vtValues b)) (index i (vtValues (mergeVT a b))))))

||| tickVT advances the ticking process's own entry by exactly one (theorem `tickVTAdvances`).
public export
testTickVTAdvances : ActuallyProvenTest
testTickVTAdvances =
  provenTest (orderingLawsTestId 8)
    "proven tickVT: advances its own entry by one"
    (discharged "tickVTAdvances")
    (singleton (rung "Total proof under %default total"
                     lawsFile Nothing `{tickVTAdvances}
                     ({n : Nat} -> (i : Fin n) -> (a : VectorTimestamp n) ->
                      index i (vtValues (tickVT i a)) = S (index i (vtValues a)))))

-- -----------------------------------------------------------------------------
-- Reject controls: each must FAIL to typecheck, or this file does not compile
-- -----------------------------------------------------------------------------

-- Merge is a join, not a sum: merging [1] with [1] is [1], never [2].
failing "Mismatch between"
  mergeIsNotSum : mergeVT (MkVectorTimestamp [1]) (MkVectorTimestamp [1])
                    = MkVectorTimestamp [2]
  mergeIsNotSum = Refl

-- Tick is not idempotent: ticking a zero clock does not leave it at zero.
failing "Mismatch between"
  tickIsNotIdempotent : tickVT FZ (MkVectorTimestamp [0]) = MkVectorTimestamp [0]
  tickIsNotIdempotent = Refl

-- A rung cannot cite one theorem for another's law: `mergeVTIdem` does not
-- prove commutativity, so the citation cannot be forged.
failing "Error during reflection"
  forgedCitation : Witnessed
  forgedCitation =
    rung "forged" lawsFile Nothing `{mergeVTIdem}
         ({n : Nat} -> (a, b : VectorTimestamp n) -> mergeVT a b = mergeVT b a)

||| Every Actually-Proven proven ordering-law test, in id order.
public export
allOrderingLawsTests : List ActuallyProvenTest
allOrderingLawsTests = [
    testMergeVTComm,
    testMergeVTAssoc,
    testMergeVTIdem,
    testMergeVTZeroL,
    testMergeVTZeroR,
    testMergeVTUpperL,
    testMergeVTUpperR,
    testTickVTAdvances
  ]
