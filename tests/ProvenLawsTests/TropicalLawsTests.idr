-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenLawsTests.TropicalLawsTests

import ProvenTests.Tropical
import ProvenTests.Framework
import ProvenTests.Types
import Data.List1

%default total

-- =============================================================================
-- TROPICAL + MAX-PLUS LAWS AS ACTUALLY-PROVEN TESTS
-- =============================================================================
-- One `provenTest` per law added to src/ProvenTests/Tropical.idr when the
-- min-plus structure was completed into a semiring and the max-plus structure
-- for worst-case bench bounds was added.
--
-- Unlike LawsTests, the citation here is TYPE-CHECKED, not only a string: each
-- test passes the theorem to `cite` at the law's full statement, written out
-- again below. If a theorem is deleted, renamed, or its statement weakened,
-- this file stops compiling. The ladder's theorem string is still metadata.
-- The runtime body is `assertTrue True`: the law was discharged at compile
-- time, and re-checking one sample at run time would add nothing.

||| The TestId of the n-th tropical / max-plus law test.
private
tropicalLawsTestId : Nat -> TestId
tropicalLawsTestId n =
  MkTestId "ProvenTests.TropicalLawsTests" ("test_" ++ show n) n

||| One proof-ladder step citing a theorem in Tropical.idr by name.
private
tstep : String -> String -> ProofStep
tstep desc thm =
  MkProofStep desc (Just "src/ProvenTests/Tropical.idr") Nothing (Just thm)

||| Runtime body of a law test. The erased first argument must be a proof of
||| the law at its stated type, so the citation is checked by the compiler.
private
cite : {0 law : Type} -> (0 _ : law) -> String -> IO TestResult
cite _ thm =
  assertTrue True ("discharged at compile time by " ++ thm ++ " in Tropical.idr")

||| min-plus: otimes is associative, for all inputs (theorem `otimesAssoc`).
public export
testOtimesAssoc : ActuallyProvenTest
testOtimesAssoc =
  provenTest (tropicalLawsTestId 1)
    "min-plus: otimes is associative"
    (cite (the ((a, b, c : ExtNat) -> otimes a (otimes b c) = otimes (otimes a b) c) otimesAssoc) "otimesAssoc")
    (singleton (tstep "Total proof under %default total" "otimesAssoc"))

||| min-plus: Fin 0 is the left identity of otimes, for all inputs (theorem `otimesIdentityL`).
public export
testOtimesIdentityL : ActuallyProvenTest
testOtimesIdentityL =
  provenTest (tropicalLawsTestId 2)
    "min-plus: Fin 0 is the left identity of otimes"
    (cite (the ((a : ExtNat) -> otimes (Fin 0) a = a) otimesIdentityL) "otimesIdentityL")
    (singleton (tstep "Total proof under %default total" "otimesIdentityL"))

||| min-plus: otimes distributes over oplus (left), for all inputs (theorem `otimesDistribL`).
public export
testOtimesDistribL : ActuallyProvenTest
testOtimesDistribL =
  provenTest (tropicalLawsTestId 3)
    "min-plus: otimes distributes over oplus (left)"
    (cite (the ((a, b, c : ExtNat) -> otimes a (oplus b c) = oplus (otimes a b) (otimes a c)) otimesDistribL) "otimesDistribL")
    (singleton (tstep "Total proof under %default total" "otimesDistribL"))

||| min-plus: otimes distributes over oplus (right), for all inputs (theorem `otimesDistribR`).
public export
testOtimesDistribR : ActuallyProvenTest
testOtimesDistribR =
  provenTest (tropicalLawsTestId 4)
    "min-plus: otimes distributes over oplus (right)"
    (cite (the ((a, b, c : ExtNat) -> otimes (oplus b c) a = oplus (otimes b a) (otimes c a)) otimesDistribR) "otimesDistribR")
    (singleton (tstep "Total proof under %default total" "otimesDistribR"))

||| min-plus: PosInf annihilates otimes (left), for all inputs (theorem `otimesAbsorbL`).
public export
testOtimesAbsorbL : ActuallyProvenTest
testOtimesAbsorbL =
  provenTest (tropicalLawsTestId 5)
    "min-plus: PosInf annihilates otimes (left)"
    (cite (the ((a : ExtNat) -> otimes PosInf a = PosInf) otimesAbsorbL) "otimesAbsorbL")
    (singleton (tstep "Total proof under %default total" "otimesAbsorbL"))

||| min-plus: PosInf annihilates otimes (right), for all inputs (theorem `otimesAbsorbR`).
public export
testOtimesAbsorbR : ActuallyProvenTest
testOtimesAbsorbR =
  provenTest (tropicalLawsTestId 6)
    "min-plus: PosInf annihilates otimes (right)"
    (cite (the ((a : ExtNat) -> otimes a PosInf = PosInf) otimesAbsorbR) "otimesAbsorbR")
    (singleton (tstep "Total proof under %default total" "otimesAbsorbR"))

||| max-plus: max is commutative, for all inputs (theorem `mpOplusComm`).
public export
testMpOplusComm : ActuallyProvenTest
testMpOplusComm =
  provenTest (tropicalLawsTestId 7)
    "max-plus: max is commutative"
    (cite (the ((a, b : Nat) -> mpOplus a b = mpOplus b a) mpOplusComm) "mpOplusComm")
    (singleton (tstep "Total proof under %default total" "mpOplusComm"))

||| max-plus: max is associative, for all inputs (theorem `mpOplusAssoc`).
public export
testMpOplusAssoc : ActuallyProvenTest
testMpOplusAssoc =
  provenTest (tropicalLawsTestId 8)
    "max-plus: max is associative"
    (cite (the ((a, b, c : Nat) -> mpOplus a (mpOplus b c) = mpOplus (mpOplus a b) c) mpOplusAssoc) "mpOplusAssoc")
    (singleton (tstep "Total proof under %default total" "mpOplusAssoc"))

||| max-plus: max is idempotent, for all inputs (theorem `mpOplusIdem`).
public export
testMpOplusIdem : ActuallyProvenTest
testMpOplusIdem =
  provenTest (tropicalLawsTestId 9)
    "max-plus: max is idempotent"
    (cite (the ((a : Nat) -> mpOplus a a = a) mpOplusIdem) "mpOplusIdem")
    (singleton (tstep "Total proof under %default total" "mpOplusIdem"))

||| max-plus: 0 is the left identity of max, for all inputs (theorem `mpOplusIdentityL`).
public export
testMpOplusIdentityL : ActuallyProvenTest
testMpOplusIdentityL =
  provenTest (tropicalLawsTestId 10)
    "max-plus: 0 is the left identity of max"
    (cite (the ((a : Nat) -> mpOplus 0 a = a) mpOplusIdentityL) "mpOplusIdentityL")
    (singleton (tstep "Total proof under %default total" "mpOplusIdentityL"))

||| max-plus: 0 is the right identity of max, for all inputs (theorem `mpOplusIdentityR`).
public export
testMpOplusIdentityR : ActuallyProvenTest
testMpOplusIdentityR =
  provenTest (tropicalLawsTestId 11)
    "max-plus: 0 is the right identity of max"
    (cite (the ((a : Nat) -> mpOplus a 0 = a) mpOplusIdentityR) "mpOplusIdentityR")
    (singleton (tstep "Total proof under %default total" "mpOplusIdentityR"))

||| max-plus: + is commutative, for all inputs (theorem `mpOtimesComm`).
public export
testMpOtimesComm : ActuallyProvenTest
testMpOtimesComm =
  provenTest (tropicalLawsTestId 12)
    "max-plus: + is commutative"
    (cite (the ((a, b : Nat) -> mpOtimes a b = mpOtimes b a) mpOtimesComm) "mpOtimesComm")
    (singleton (tstep "Total proof under %default total" "mpOtimesComm"))

||| max-plus: + is associative, for all inputs (theorem `mpOtimesAssoc`).
public export
testMpOtimesAssoc : ActuallyProvenTest
testMpOtimesAssoc =
  provenTest (tropicalLawsTestId 13)
    "max-plus: + is associative"
    (cite (the ((a, b, c : Nat) -> mpOtimes a (mpOtimes b c) = mpOtimes (mpOtimes a b) c) mpOtimesAssoc) "mpOtimesAssoc")
    (singleton (tstep "Total proof under %default total" "mpOtimesAssoc"))

||| max-plus: 0 is the left identity of +, for all inputs (theorem `mpOtimesIdentityL`).
public export
testMpOtimesIdentityL : ActuallyProvenTest
testMpOtimesIdentityL =
  provenTest (tropicalLawsTestId 14)
    "max-plus: 0 is the left identity of +"
    (cite (the ((a : Nat) -> mpOtimes 0 a = a) mpOtimesIdentityL) "mpOtimesIdentityL")
    (singleton (tstep "Total proof under %default total" "mpOtimesIdentityL"))

||| max-plus: 0 is the right identity of +, for all inputs (theorem `mpOtimesIdentityR`).
public export
testMpOtimesIdentityR : ActuallyProvenTest
testMpOtimesIdentityR =
  provenTest (tropicalLawsTestId 15)
    "max-plus: 0 is the right identity of +"
    (cite (the ((a : Nat) -> mpOtimes a 0 = a) mpOtimesIdentityR) "mpOtimesIdentityR")
    (singleton (tstep "Total proof under %default total" "mpOtimesIdentityR"))

||| max-plus: + distributes over max (left), for all inputs (theorem `mpDistribL`).
public export
testMpDistribL : ActuallyProvenTest
testMpDistribL =
  provenTest (tropicalLawsTestId 16)
    "max-plus: + distributes over max (left)"
    (cite (the ((a, b, c : Nat) -> mpOtimes a (mpOplus b c) = mpOplus (mpOtimes a b) (mpOtimes a c)) mpDistribL) "mpDistribL")
    (singleton (tstep "Total proof under %default total" "mpDistribL"))

||| max-plus: + distributes over max (right), for all inputs (theorem `mpDistribR`).
public export
testMpDistribR : ActuallyProvenTest
testMpDistribR =
  provenTest (tropicalLawsTestId 17)
    "max-plus: + distributes over max (right)"
    (cite (the ((a, b, c : Nat) -> mpOtimes (mpOplus b c) a = mpOplus (mpOtimes b a) (mpOtimes c a)) mpDistribR) "mpDistribR")
    (singleton (tstep "Total proof under %default total" "mpDistribR"))

-- =============================================================================
-- REJECT CONTROLS: false laws must NOT typecheck
-- =============================================================================
-- Each block states a law that does not hold and requires the type checker to
-- reject it. The expected-message substring is pinned so a block cannot pass
-- on an unrelated error (a typo, a scoping slip). Measured 2026-10-06 on
-- Idris2 0.7.0 by checking each body outside `failing`: both report a
-- "Mismatch between" of two distinct numerals.

-- Max-plus is NOT a semiring: the max identity 0 does not annihilate +.
failing "Mismatch between"
  maxPlusZeroAnnihilates : mpOtimes 0 3 = 0
  maxPlusZeroAnnihilates = Refl

-- Min-plus otimes is NOT idempotent: Fin 2 otimes Fin 2 is Fin 4.
failing "Mismatch between"
  minPlusOtimesIdempotent : otimes (Fin 2) (Fin 2) = Fin 2
  minPlusOtimesIdempotent = Refl

||| Every Actually-Proven tropical / max-plus law test, in id order.
public export
allTropicalLawsTests : List ActuallyProvenTest
allTropicalLawsTests = [
    testOtimesAssoc,
    testOtimesIdentityL,
    testOtimesDistribL,
    testOtimesDistribR,
    testOtimesAbsorbL,
    testOtimesAbsorbR,
    testMpOplusComm,
    testMpOplusAssoc,
    testMpOplusIdem,
    testMpOplusIdentityL,
    testMpOplusIdentityR,
    testMpOtimesComm,
    testMpOtimesAssoc,
    testMpOtimesIdentityL,
    testMpOtimesIdentityR,
    testMpDistribL,
    testMpDistribR
  ]
