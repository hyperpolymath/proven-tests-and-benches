-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Tropical

import Data.Nat
import Data.List1

%default total

-- =============================================================================
-- THE TROPICAL (MIN-PLUS) SEMIRING — the shared math
-- =============================================================================
-- One canonical, machine-checked min-plus semiring over ℕ ∪ {∞}:
--   ⊕ (oplus)  = min   (additive op;       identity = PosInf)
--   ⊗ (otimes) = +     (multiplicative op; identity = Fin 0; PosInf absorbs)
--
-- This is the single source of truth for two consumers across the ecosystem:
--   * bag-of-actions — the mesh planner's "cheapest capable node" is ⊕ = min
--     over integer node costs (Bag.Planner / Bag.Estate.cheapestCapable).
--   * proven-tests   — the Tropical resource-bound tests
--     (ProvenTests.TypeSafe.Tropical) are the *applied, Double-valued, sampled*
--     view of this same algebra.
--
-- The laws below are TOTAL Idris2 proofs: if this module compiles, they hold for
-- every input (a real ∀-proof), which is what makes the tropical-laws test
-- genuinely Actually-Proven rather than merely sampled.
--
-- Min-plus laws proved: ⊕ commutative, associative, idempotent, identity PosInf
-- (both sides); ⊗ commutative, associative, identity Fin 0 (both sides); ⊗
-- distributes over ⊕ (left and right); PosInf annihilates ⊗ (both sides).
-- Together these are every commutative-semiring axiom, so the structure is a
-- commutative, ⊕-idempotent semiring.
--
-- The end of this module also carries a MAX-PLUS structure over Nat for
-- worst-case bench bounds. It is NOT a semiring; its own header lists exactly
-- which laws are proved and which do not hold. It lives here rather than in its
-- own module because a new library module changes the module count asserted
-- in the machine-readable state file, which this change does not edit.

--/ The tropical carrier: a natural number, or +∞.
public export
data ExtNat : Type where
  Fin : Nat -> ExtNat
  PosInf : ExtNat

public export
Show ExtNat where
  show (Fin n) = show n
  show PosInf     = "inf"

public export
Eq ExtNat where
  Fin a == Fin b = a == b
  PosInf   == PosInf   = True
  _     == _     = False

-- Structural min on Nat — defined directly (not via Ord) so the proofs are clean.
public export
minN : Nat -> Nat -> Nat
minN Z     _     = Z
minN _     Z     = Z
minN (S a) (S b) = S (minN a b)

--/ Tropical addition ⊕ = min, with PosInf as the (additive) identity.
public export
oplus : ExtNat -> ExtNat -> ExtNat
oplus PosInf     y       = y
oplus (Fin a) PosInf     = Fin a
oplus (Fin a) (Fin b) = Fin (minN a b)

--/ Tropical multiplication ⊗ = +, with Fin 0 as identity and PosInf absorbing.
public export
otimes : ExtNat -> ExtNat -> ExtNat
otimes PosInf     _       = PosInf
otimes (Fin _) PosInf     = PosInf
otimes (Fin a) (Fin b) = Fin (a + b)

--/ Total order on the carrier (everything ≤ PosInf). Drives cheapest-capable.
public export
lteEN : ExtNat -> ExtNat -> Bool
lteEN _       PosInf     = True
lteEN PosInf     (Fin _) = False
lteEN (Fin a) (Fin b) = a <= b

--/ The cheaper (⊕ = min) of two costs — the planner's core decision.
public export
cheaperOf : ExtNat -> ExtNat -> ExtNat
cheaperOf = oplus

--/ Cheapest of a non-empty list of costs (Bag.Planner over node costs).
public export
cheapest : List1 ExtNat -> ExtNat
cheapest (x ::: xs) = foldl oplus x xs

-- =============================================================================
-- MACHINE-CHECKED LAWS (total proofs; cited by the Actually-Proven test)
-- =============================================================================

-- min on Nat: commutative, idempotent, associative.
public export
minNComm : (a, b : Nat) -> minN a b = minN b a
minNComm Z     Z     = Refl
minNComm Z     (S _) = Refl
minNComm (S _) Z     = Refl
minNComm (S a) (S b) = cong S (minNComm a b)

public export
minNIdem : (a : Nat) -> minN a a = a
minNIdem Z     = Refl
minNIdem (S a) = cong S (minNIdem a)

public export
minNAssoc : (a, b, c : Nat) -> minN a (minN b c) = minN (minN a b) c
minNAssoc Z     _     _     = Refl
minNAssoc (S _) Z     _     = Refl
minNAssoc (S _) (S _) Z     = Refl
minNAssoc (S a) (S b) (S c) = cong S (minNAssoc a b c)

-- ⊕ is commutative, idempotent, associative, with PosInf as identity.
public export
oplusComm : (a, b : ExtNat) -> oplus a b = oplus b a
oplusComm PosInf     PosInf     = Refl
oplusComm PosInf     (Fin _) = Refl
oplusComm (Fin _) PosInf     = Refl
oplusComm (Fin a) (Fin b) = cong Fin (minNComm a b)

public export
oplusIdentityL : (a : ExtNat) -> oplus PosInf a = a
oplusIdentityL _ = Refl

public export
oplusIdentityR : (a : ExtNat) -> oplus a PosInf = a
oplusIdentityR PosInf     = Refl
oplusIdentityR (Fin _) = Refl

public export
oplusIdem : (a : ExtNat) -> oplus a a = a
oplusIdem PosInf     = Refl
oplusIdem (Fin a) = cong Fin (minNIdem a)

public export
oplusAssoc : (a, b, c : ExtNat) -> oplus a (oplus b c) = oplus (oplus a b) c
oplusAssoc PosInf     _       _       = Refl
oplusAssoc (Fin _) PosInf     _       = Refl
oplusAssoc (Fin _) (Fin _) PosInf     = Refl
oplusAssoc (Fin a) (Fin b) (Fin c) = cong Fin (minNAssoc a b c)

-- ⊗ has identity Fin 0 and is commutative.
public export
otimesIdentityR : (a : ExtNat) -> otimes a (Fin 0) = a
otimesIdentityR PosInf     = Refl
otimesIdentityR (Fin a) = cong Fin (plusZeroRightNeutral a)

public export
otimesComm : (a, b : ExtNat) -> otimes a b = otimes b a
otimesComm PosInf     PosInf     = Refl
otimesComm PosInf     (Fin _) = Refl
otimesComm (Fin _) PosInf     = Refl
otimesComm (Fin a) (Fin b) = cong Fin (plusCommutative a b)

-- A single-element cheapest is that element (base case of the planner fold).
public export
cheapestSingleton : (x : ExtNat) -> cheapest (x ::: []) = x
cheapestSingleton _ = Refl

-- =============================================================================
-- COMPLETING THE SEMIRING: ⊗ associativity, left identity, distributivity,
-- and PosInf annihilation. With these, (ExtNat, oplus, otimes, PosInf, Fin 0)
-- satisfies every commutative-semiring axiom, each by a total proof.
-- =============================================================================

||| Addition distributes over minN from the left: a + min b c = min (a+b) (a+c).
public export
plusMinNDistribL : (a, b, c : Nat) -> a + minN b c = minN (a + b) (a + c)
plusMinNDistribL Z     _ _ = Refl
plusMinNDistribL (S a) b c = cong S (plusMinNDistribL a b c)

||| Addition distributes over minN from the right: min b c + a = min (b+a) (c+a).
public export
plusMinNDistribR : (a, b, c : Nat) -> minN b c + a = minN (b + a) (c + a)
plusMinNDistribR a b c =
  rewrite plusCommutative (minN b c) a in
  rewrite plusCommutative b a in
  rewrite plusCommutative c a in
  plusMinNDistribL a b c

||| Fin 0 is a left identity for ⊗ (the right identity is otimesIdentityR).
public export
otimesIdentityL : (a : ExtNat) -> otimes (Fin 0) a = a
otimesIdentityL PosInf  = Refl
otimesIdentityL (Fin _) = Refl

||| ⊗ is associative.
public export
otimesAssoc : (a, b, c : ExtNat) -> otimes a (otimes b c) = otimes (otimes a b) c
otimesAssoc PosInf  _       _       = Refl
otimesAssoc (Fin _) PosInf  _       = Refl
otimesAssoc (Fin _) (Fin _) PosInf  = Refl
otimesAssoc (Fin a) (Fin b) (Fin c) = cong Fin (plusAssociative a b c)

||| PosInf annihilates ⊗ on the left: PosInf ⊗ x = PosInf.
public export
otimesAbsorbL : (a : ExtNat) -> otimes PosInf a = PosInf
otimesAbsorbL _ = Refl

||| PosInf annihilates ⊗ on the right: x ⊗ PosInf = PosInf.
public export
otimesAbsorbR : (a : ExtNat) -> otimes a PosInf = PosInf
otimesAbsorbR PosInf  = Refl
otimesAbsorbR (Fin _) = Refl

||| ⊗ distributes over ⊕ from the left: a ⊗ (b ⊕ c) = (a ⊗ b) ⊕ (a ⊗ c).
public export
otimesDistribL : (a, b, c : ExtNat) ->
                 otimes a (oplus b c) = oplus (otimes a b) (otimes a c)
otimesDistribL PosInf  _       _       = Refl
otimesDistribL (Fin _) PosInf  _       = Refl
otimesDistribL (Fin _) (Fin _) PosInf  = Refl
otimesDistribL (Fin a) (Fin b) (Fin c) = cong Fin (plusMinNDistribL a b c)

||| ⊗ distributes over ⊕ from the right: (b ⊕ c) ⊗ a = (b ⊗ a) ⊕ (c ⊗ a).
public export
otimesDistribR : (a, b, c : ExtNat) ->
                 otimes (oplus b c) a = oplus (otimes b a) (otimes c a)
otimesDistribR _       PosInf  _       = Refl
otimesDistribR PosInf  (Fin _) PosInf  = Refl
otimesDistribR (Fin _) (Fin _) PosInf  = Refl
otimesDistribR PosInf  (Fin _) (Fin _) = Refl
otimesDistribR (Fin a) (Fin b) (Fin c) = cong Fin (plusMinNDistribR a b c)

-- =============================================================================
-- MAX-PLUS OVER Nat — worst-case bench bounds
-- =============================================================================
-- A worst-case cost bound composes two ways:
--   * sequential composition  (do p, then q)        bound = p + q   (mpOtimes)
--   * branch                  (do p or q, unknown)  bound = max p q (mpOplus)
--
-- PROVED below (total, for every input):
--   mpOplus  (max): commutative, associative, idempotent, identity 0 (both sides)
--   mpOtimes (+):   commutative, associative, identity 0 (both sides)
--   mpOtimes distributes over mpOplus, on the left and on the right
--
-- DOES NOT HOLD, so this is NOT a semiring:
--   The ⊕-identity 0 does not annihilate ⊗: mpOtimes 0 a = a, not 0. A semiring
--   needs a zero with 0 ⊗ a = 0; over plain Nat the only candidate is the
--   max-identity 0, which is also the +-identity. (Adjoining a NegInf bottom
--   would restore annihilation; it is deliberately omitted because a bench
--   bound is never -∞.) The rejection of that law is checked by a `failing`
--   block in tests/ProvenLawsTests/TropicalLawsTests.idr.
--   ⊗ is not idempotent either (a + a /= a for a > 0), as expected.
-- What remains is a commutative "presemiring" (semiring minus annihilation)
-- whose ⊕ is idempotent and whose two units coincide.

||| Structural max on Nat, defined directly (not via Ord) so the proofs are clean.
public export
maxN : Nat -> Nat -> Nat
maxN Z     b     = b
maxN a     Z     = a
maxN (S a) (S b) = S (maxN a b)

||| Max-plus ⊕ = max: the bound of a branch whose taken arm is unknown.
public export
mpOplus : Nat -> Nat -> Nat
mpOplus = maxN

||| Max-plus ⊗ = +: the bound of sequential composition.
public export
mpOtimes : Nat -> Nat -> Nat
mpOtimes = plus

||| maxN is commutative.
public export
maxNComm : (a, b : Nat) -> maxN a b = maxN b a
maxNComm Z     Z     = Refl
maxNComm Z     (S _) = Refl
maxNComm (S _) Z     = Refl
maxNComm (S a) (S b) = cong S (maxNComm a b)

||| maxN is idempotent.
public export
maxNIdem : (a : Nat) -> maxN a a = a
maxNIdem Z     = Refl
maxNIdem (S a) = cong S (maxNIdem a)

||| maxN is associative.
public export
maxNAssoc : (a, b, c : Nat) -> maxN a (maxN b c) = maxN (maxN a b) c
maxNAssoc Z     _     _     = Refl
maxNAssoc (S _) Z     _     = Refl
maxNAssoc (S _) (S _) Z     = Refl
maxNAssoc (S a) (S b) (S c) = cong S (maxNAssoc a b c)

||| 0 is the right identity of maxN.
public export
maxNZeroR : (a : Nat) -> maxN a 0 = a
maxNZeroR Z     = Refl
maxNZeroR (S _) = Refl

||| Addition distributes over maxN from the left: a + max b c = max (a+b) (a+c).
public export
plusMaxNDistribL : (a, b, c : Nat) -> a + maxN b c = maxN (a + b) (a + c)
plusMaxNDistribL Z     _ _ = Refl
plusMaxNDistribL (S a) b c = cong S (plusMaxNDistribL a b c)

||| Addition distributes over maxN from the right: max b c + a = max (b+a) (c+a).
public export
plusMaxNDistribR : (a, b, c : Nat) -> maxN b c + a = maxN (b + a) (c + a)
plusMaxNDistribR a b c =
  rewrite plusCommutative (maxN b c) a in
  rewrite plusCommutative b a in
  rewrite plusCommutative c a in
  plusMaxNDistribL a b c

||| Max-plus ⊕ is commutative.
public export
mpOplusComm : (a, b : Nat) -> mpOplus a b = mpOplus b a
mpOplusComm = maxNComm

||| Max-plus ⊕ is associative.
public export
mpOplusAssoc : (a, b, c : Nat) ->
               mpOplus a (mpOplus b c) = mpOplus (mpOplus a b) c
mpOplusAssoc = maxNAssoc

||| Max-plus ⊕ is idempotent.
public export
mpOplusIdem : (a : Nat) -> mpOplus a a = a
mpOplusIdem = maxNIdem

||| 0 is the left identity of max-plus ⊕.
public export
mpOplusIdentityL : (a : Nat) -> mpOplus 0 a = a
mpOplusIdentityL _ = Refl

||| 0 is the right identity of max-plus ⊕.
public export
mpOplusIdentityR : (a : Nat) -> mpOplus a 0 = a
mpOplusIdentityR = maxNZeroR

||| Max-plus ⊗ is commutative.
public export
mpOtimesComm : (a, b : Nat) -> mpOtimes a b = mpOtimes b a
mpOtimesComm = plusCommutative

||| Max-plus ⊗ is associative.
public export
mpOtimesAssoc : (a, b, c : Nat) ->
                mpOtimes a (mpOtimes b c) = mpOtimes (mpOtimes a b) c
mpOtimesAssoc = plusAssociative

||| 0 is the left identity of max-plus ⊗.
public export
mpOtimesIdentityL : (a : Nat) -> mpOtimes 0 a = a
mpOtimesIdentityL _ = Refl

||| 0 is the right identity of max-plus ⊗.
public export
mpOtimesIdentityR : (a : Nat) -> mpOtimes a 0 = a
mpOtimesIdentityR = plusZeroRightNeutral

||| Max-plus ⊗ distributes over ⊕ from the left.
public export
mpDistribL : (a, b, c : Nat) ->
             mpOtimes a (mpOplus b c) = mpOplus (mpOtimes a b) (mpOtimes a c)
mpDistribL = plusMaxNDistribL

||| Max-plus ⊗ distributes over ⊕ from the right.
public export
mpDistribR : (a, b, c : Nat) ->
             mpOtimes (mpOplus b c) a = mpOplus (mpOtimes b a) (mpOtimes c a)
mpDistribR = plusMaxNDistribR
