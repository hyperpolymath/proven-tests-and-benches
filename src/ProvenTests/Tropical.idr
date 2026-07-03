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
