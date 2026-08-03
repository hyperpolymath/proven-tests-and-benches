-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.HigherOrder.Traversal

import Data.List

-- =============================================================================
-- TRAVERSAL LAWS
-- =============================================================================
-- Spec: HigherOrder/Traversal.idr.
--
-- A traversal visits every element exactly once and preserves shape. The two
-- properties that matter operationally are length preservation and the fusion
-- law (two passes collapse into one). Stated over concrete witnesses — the
-- Provisionally-Proven tier.

-- --- Shape preservation -----------------------------------------------------

--/ A traversal preserves length.
public export
traversalPreservesLength : (a -> b) -> List a -> Bool
traversalPreservesLength f xs = length (map f xs) == length xs

--/ A traversal preserves emptiness in both directions.
public export
traversalPreservesEmpty : (a -> b) -> List a -> Bool
traversalPreservesEmpty f xs = isNil (map f xs) == isNil xs

-- --- Fusion -----------------------------------------------------------------

--/ Two traversals fuse into one: map g . map f = map (g . f).
public export
traversalFusionAt : Eq c => (b -> c) -> (a -> b) -> List a -> Bool
traversalFusionAt g f xs = (map g . map f) xs == map (g . f) xs

-- --- Order -------------------------------------------------------------------

--/ A traversal visits in order: reversing before and after are the same as
--/ mapping over the reverse.
public export
traversalRespectsOrder : Eq b => (a -> b) -> List a -> Bool
traversalRespectsOrder f xs = map f (reverse xs) == reverse (map f xs)

-- --- Effectful traversal ----------------------------------------------------

--/ `traverse` with a Just-returning function is `Just . map`.
public export
traverseMaybeTotal : Eq b => (a -> b) -> List a -> Bool
traverseMaybeTotal f xs = traverse (Just . f) xs == Just (map f xs)

--/ `traverse` short-circuits: one Nothing makes the whole traversal Nothing.
--/ On [] the result is `Just []`, so the property is stated only for non-empty
--/ input rather than made vacuously true for every list.
public export
traverseMaybeShortCircuits : List a -> Bool
traverseMaybeShortCircuits xs =
  case xs of
    []      => True   -- vacuous: nothing to fail on
    (_::_)  => case traverse (\_ => the (Maybe ()) Nothing) xs of
                 Nothing => True
                 Just _  => False

-- --- Concrete witnesses -----------------------------------------------------

public export
exampleWords : List String
exampleWords = ["alpha", "beta", "gamma", "delta"]

public export
exampleLengths : List Nat
exampleLengths = [1, 2, 3, 4, 5]
