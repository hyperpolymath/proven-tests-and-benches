-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.OrderingLaws

import Proven.SafeOrdering
import Data.Nat
import Data.Vect

%default total

-- =============================================================================
-- Laws of proven's vector-clock merge, proved against proven's own definition
-- =============================================================================
-- `Proven.SafeOrdering.mergeVT` is imported from proven at the SHA pinned in
-- integrations/proven/PROVEN_PIN, not copied: every theorem below is stated
-- about proven's definition, so a change to it that breaks a law stops this
-- package compiling at the next pin bump.
--
-- A vector clock is only sound if merge is a join-semilattice operation with
-- the zero clock as identity: commutativity and associativity make the merged
-- clock independent of message order, idempotence makes redelivery harmless,
-- and the upper-bound law is what lets a merged clock dominate both inputs.

-- -----------------------------------------------------------------------------
-- Nat: Prelude `max` agrees with Data.Nat.maximum
-- -----------------------------------------------------------------------------

||| Prelude max on Nat commutes with successor.
maxSucc : (x, y : Nat) -> max (S x) (S y) = S (max x y)
maxSucc x y with (compareNat x y)
  _ | LT = Refl
  _ | EQ = Refl
  _ | GT = Refl

||| The Prelude `Ord Nat` max (used by mergeVT) is Data.Nat.maximum.
export
maxIsMaximum : (x, y : Nat) -> max x y = maximum x y
maxIsMaximum Z     Z     = Refl
maxIsMaximum Z     (S _) = Refl
maxIsMaximum (S _) Z     = Refl
maxIsMaximum (S x) (S y) =
  trans (maxSucc x y) (cong S (maxIsMaximum x y))

||| Prelude max on Nat is commutative.
maxComm : (x, y : Nat) -> max x y = max y x
maxComm x y =
  trans (maxIsMaximum x y)
        (trans (maximumCommutative x y) (sym (maxIsMaximum y x)))

||| Prelude max on Nat is associative.
maxAssoc : (x, y, z : Nat) -> max x (max y z) = max (max x y) z
maxAssoc x y z =
  trans (cong (max x) (maxIsMaximum y z))
  (trans (maxIsMaximum x (maximum y z))
  (trans (maximumAssociative x y z)
  (trans (sym (maxIsMaximum (maximum x y) z))
         (cong (\w => max w z) (sym (maxIsMaximum x y))))))

||| Prelude max on Nat is idempotent.
maxIdem : (x : Nat) -> max x x = x
maxIdem x = trans (maxIsMaximum x x) (maximumIdempotent x)

||| Zero is a left identity of Prelude max on Nat.
maxZeroL : (x : Nat) -> max Z x = x
maxZeroL x = maxIsMaximum Z x

-- -----------------------------------------------------------------------------
-- Vect: pointwise max
-- -----------------------------------------------------------------------------

||| Pointwise max is commutative.
zipMaxComm : (xs, ys : Vect n Nat) -> zipWith Prelude.max xs ys = zipWith Prelude.max ys xs
zipMaxComm []        []        = Refl
zipMaxComm (x :: xs) (y :: ys) = cong2 (::) (maxComm x y) (zipMaxComm xs ys)

||| Pointwise max is associative.
zipMaxAssoc : (xs, ys, zs : Vect n Nat) ->
              zipWith Prelude.max xs (zipWith Prelude.max ys zs)
                = zipWith Prelude.max (zipWith Prelude.max xs ys) zs
zipMaxAssoc []        []        []        = Refl
zipMaxAssoc (x :: xs) (y :: ys) (z :: zs) =
  cong2 (::) (maxAssoc x y z) (zipMaxAssoc xs ys zs)

||| Pointwise max is idempotent.
zipMaxIdem : (xs : Vect n Nat) -> zipWith Prelude.max xs xs = xs
zipMaxIdem []        = Refl
zipMaxIdem (x :: xs) = cong2 (::) (maxIdem x) (zipMaxIdem xs)

||| The all-zero vector is a left identity of pointwise max.
zipMaxZeroL : (xs : Vect n Nat) -> zipWith Prelude.max (replicate n Z) xs = xs
zipMaxZeroL []        = Refl
zipMaxZeroL (x :: xs) = cong2 (::) (maxZeroL x) (zipMaxZeroL xs)

-- -----------------------------------------------------------------------------
-- The laws of mergeVT
-- -----------------------------------------------------------------------------

||| mergeVT is commutative: merge order does not change the merged clock.
export
mergeVTComm : {n : Nat} -> (a, b : VectorTimestamp n) -> mergeVT a b = mergeVT b a
mergeVTComm (MkVectorTimestamp xs) (MkVectorTimestamp ys) =
  cong MkVectorTimestamp (zipMaxComm xs ys)

||| mergeVT is associative: merging a batch does not depend on grouping.
export
mergeVTAssoc : {n : Nat} -> (a, b, c : VectorTimestamp n) ->
               mergeVT a (mergeVT b c) = mergeVT (mergeVT a b) c
mergeVTAssoc (MkVectorTimestamp xs) (MkVectorTimestamp ys) (MkVectorTimestamp zs) =
  cong MkVectorTimestamp (zipMaxAssoc xs ys zs)

||| mergeVT is idempotent: redelivering a clock changes nothing.
export
mergeVTIdem : {n : Nat} -> (a : VectorTimestamp n) -> mergeVT a a = a
mergeVTIdem (MkVectorTimestamp xs) = cong MkVectorTimestamp (zipMaxIdem xs)

||| zeroVT is a left identity of mergeVT.
export
mergeVTZeroL : {n : Nat} -> (a : VectorTimestamp n) -> mergeVT Proven.SafeOrdering.zeroVT a = a
mergeVTZeroL (MkVectorTimestamp xs) = cong MkVectorTimestamp (zipMaxZeroL xs)

||| zeroVT is a right identity of mergeVT.
export
mergeVTZeroR : {n : Nat} -> (a : VectorTimestamp n) -> mergeVT a Proven.SafeOrdering.zeroVT = a
mergeVTZeroR a = trans (mergeVTComm a zeroVT) (mergeVTZeroL a)

-- -----------------------------------------------------------------------------
-- Per-process laws: what merge and tick do to one process's entry
-- -----------------------------------------------------------------------------

||| Indexing a pointwise max is the max of the indexed entries.
indexZipMax : (i : Fin n) -> (xs, ys : Vect n Nat) ->
              index i (zipWith Prelude.max xs ys) = max (index i xs) (index i ys)
indexZipMax FZ     (x :: _)  (y :: _)  = Refl
indexZipMax (FS i) (_ :: xs) (_ :: ys) = indexZipMax i xs ys

||| Bumping entry i with S makes entry i one larger.
indexUpdateSucc : (i : Fin n) -> (xs : Vect n Nat) ->
                  index i (updateAt i S xs) = S (index i xs)
indexUpdateSucc FZ     (_ :: _)  = Refl
indexUpdateSucc (FS i) (_ :: xs) = indexUpdateSucc i xs

||| Merge dominates its left input at every process: no entry of a clock
||| can go backwards by merging another clock into it.
export
mergeVTUpperL : {n : Nat} -> (i : Fin n) -> (a, b : VectorTimestamp n) ->
                LTE (index i (vtValues a)) (index i (vtValues (mergeVT a b)))
mergeVTUpperL i (MkVectorTimestamp xs) (MkVectorTimestamp ys) =
  rewrite indexZipMax i xs ys in
  rewrite maxIsMaximum (index i xs) (index i ys) in
  maximumLeftUpperBound (index i xs) (index i ys)

||| Merge dominates its right input at every process.
export
mergeVTUpperR : {n : Nat} -> (i : Fin n) -> (a, b : VectorTimestamp n) ->
                LTE (index i (vtValues b)) (index i (vtValues (mergeVT a b)))
mergeVTUpperR i a b = rewrite mergeVTComm a b in mergeVTUpperL i b a

||| Ticking process i advances exactly its own entry by one.
export
tickVTAdvances : {n : Nat} -> (i : Fin n) -> (a : VectorTimestamp n) ->
                 index i (vtValues (tickVT i a)) = S (index i (vtValues a))
tickVTAdvances i (MkVectorTimestamp xs) = indexUpdateSucc i xs
