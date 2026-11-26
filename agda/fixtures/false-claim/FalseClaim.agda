-- SPDX-License-Identifier: MPL-2.0
-- NEGATIVE CONTROL: must be REJECTED by the type checker. If this ever
-- passes, the gate is vacuous.
{-# OPTIONS --safe --cubical-compatible #-}
module FalseClaim where

data ℕ : Set where
  zero : ℕ
  suc  : ℕ → ℕ

data _≡_ {A : Set} (x : A) : A → Set where
  refl : x ≡ x

bogus : zero ≡ suc zero
bogus = refl
