-- SPDX-License-Identifier: MPL-2.0
-- Sweep-1 template for Agda: UT and P2P as PROOFS; BLD = it type-checks.
-- Gate: scripts/agda-prove.sh <dir>  (--safe --cubical-compatible + doubt check)
{-# OPTIONS --safe --cubical-compatible #-}
module Sweep1 where

data Bool : Set where
  true false : Bool

not : Bool → Bool
not true  = false
not false = true

data _≡_ {A : Set} (x : A) : A → Set where
  refl : x ≡ x

-- UT: every constructor case
ut-not-true  : not true ≡ false
ut-not-true  = refl
ut-not-false : not false ≡ true
ut-not-false = refl

-- P2P: two functions across one seam compose to identity (for ALL inputs)
p2p-involutive : ∀ b → not (not b) ≡ b
p2p-involutive true  = refl
p2p-involutive false = refl
