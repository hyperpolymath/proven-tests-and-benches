-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.SetTheory.Basics

import Data.List

-- =============================================================================
-- SET OPERATIONS
-- =============================================================================
-- Spec: SetTheory/Basics.idr — "Set operations".
--
-- Sets are modelled as duplicate-free sorted lists. That representation is
-- chosen so equality is decidable structurally, which is what lets these laws
-- be *checked* rather than merely asserted. The normalisation step is part of
-- the model, not a convenience: without it, list equality is order-sensitive
-- and none of the commutativity laws below would hold.

-- --- The model ---------------------------------------------------------------

--/ Normalise a list into set form: sorted, duplicate-free.
public export
toSet : Ord a => List a -> List a
toSet = nub . sort

--/ Set membership.
public export
member : Eq a => a -> List a -> Bool
member x xs = elem x xs

--/ Union.
public export
union' : Ord a => List a -> List a -> List a
union' xs ys = toSet (xs ++ ys)

--/ Intersection.
public export
intersect' : Ord a => List a -> List a -> List a
intersect' xs ys = toSet (filter (\x => elem x ys) xs)

--/ Difference.
public export
difference' : Ord a => List a -> List a -> List a
difference' xs ys = toSet (filter (\x => not (elem x ys)) xs)

-- --- Idempotence -------------------------------------------------------------

public export
unionIdempotent : (Ord a, Eq a) => List a -> Bool
unionIdempotent xs = union' xs xs == toSet xs

public export
intersectIdempotent : (Ord a, Eq a) => List a -> Bool
intersectIdempotent xs = intersect' xs xs == toSet xs

-- --- Commutativity -----------------------------------------------------------

public export
unionCommutative : (Ord a, Eq a) => List a -> List a -> Bool
unionCommutative xs ys = union' xs ys == union' ys xs

public export
intersectCommutative : (Ord a, Eq a) => List a -> List a -> Bool
intersectCommutative xs ys = intersect' xs ys == intersect' ys xs

-- --- Associativity -----------------------------------------------------------

public export
unionAssociative : (Ord a, Eq a) => List a -> List a -> List a -> Bool
unionAssociative xs ys zs =
  union' (union' xs ys) zs == union' xs (union' ys zs)

public export
intersectAssociative : (Ord a, Eq a) => List a -> List a -> List a -> Bool
intersectAssociative xs ys zs =
  intersect' (intersect' xs ys) zs == intersect' xs (intersect' ys zs)

-- --- Identity and annihilation -----------------------------------------------

public export
unionEmptyIdentity : (Ord a, Eq a) => List a -> Bool
unionEmptyIdentity xs = union' xs [] == toSet xs

public export
intersectEmptyAnnihilates : (Ord a, Eq a) => List a -> Bool
intersectEmptyAnnihilates xs = intersect' xs [] == []

-- --- Distributivity ----------------------------------------------------------

public export
unionDistributesOverIntersect : (Ord a, Eq a) => List a -> List a -> List a -> Bool
unionDistributesOverIntersect xs ys zs =
  union' xs (intersect' ys zs) == intersect' (union' xs ys) (union' xs zs)

-- --- Difference --------------------------------------------------------------

public export
differenceSelfEmpty : (Ord a, Eq a) => List a -> Bool
differenceSelfEmpty xs = difference' xs xs == []

--/ De Morgan, relative to a universe u.
public export
deMorganUnion : (Ord a, Eq a) => List a -> List a -> List a -> Bool
deMorganUnion u xs ys =
  difference' u (union' xs ys) == intersect' (difference' u xs) (difference' u ys)

-- --- Concrete witnesses -----------------------------------------------------

public export
setA : List Int
setA = [1, 2, 3, 4]

public export
setB : List Int
setB = [3, 4, 5, 6]

public export
setC : List Int
setC = [5, 6, 7, 8]

public export
universe : List Int
universe = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
