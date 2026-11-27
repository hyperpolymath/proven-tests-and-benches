-- SPDX-License-Identifier: MPL-2.0
{-# OPTIONS --safe --cubical-compatible #-}
module Good where

data ℕ : Set where
  zero : ℕ
  suc  : ℕ → ℕ

_+_ : ℕ → ℕ → ℕ
zero  + n = n
suc m + n = suc (m + n)

infix 4 _≡_
data _≡_ {A : Set} (x : A) : A → Set where
  refl : x ≡ x

+-identityʳ : ∀ n → n + zero ≡ n
+-identityʳ zero    = refl
+-identityʳ (suc n) with n + zero | +-identityʳ n
... | .n | refl = refl
