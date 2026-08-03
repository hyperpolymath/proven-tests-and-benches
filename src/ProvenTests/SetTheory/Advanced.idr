-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.SetTheory.Advanced

import ProvenTests.SetTheory.Basics
import Data.List
import Data.Nat

-- =============================================================================
-- HIGHER SET CONCEPTS
-- =============================================================================
-- Spec: SetTheory/Advanced.idr — "Higher set concepts".
--
-- Builds on Basics: power sets, cardinality, and the subset ordering. The
-- power-set laws are the interesting ones because they relate cardinality to
-- structure (|P(S)| = 2^|S|), which catches representation bugs that the
-- lattice laws in Basics cannot.

-- --- Subset ordering ---------------------------------------------------------

public export
subset : Eq a => List a -> List a -> Bool
subset xs ys = all (\x => elem x ys) xs

public export
properSubset : (Ord a, Eq a) => List a -> List a -> Bool
properSubset xs ys = subset xs ys && not (subset ys xs)

--/ Subset is reflexive.
public export
subsetReflexive : Eq a => List a -> Bool
subsetReflexive xs = subset xs xs

--/ Subset is transitive.
public export
subsetTransitive : Eq a => List a -> List a -> List a -> Bool
subsetTransitive xs ys zs =
  not (subset xs ys && subset ys zs) || subset xs zs

--/ Antisymmetry: mutual inclusion means equality (as sets).
public export
subsetAntisymmetric : (Ord a, Eq a) => List a -> List a -> Bool
subsetAntisymmetric xs ys =
  not (subset xs ys && subset ys xs) || (toSet xs == toSet ys)

-- --- Relating subset to the lattice operations --------------------------------

--/ An intersection is a subset of each argument.
public export
intersectIsSubset : (Ord a, Eq a) => List a -> List a -> Bool
intersectIsSubset xs ys = subset (intersect' xs ys) (toSet xs)

--/ Each argument is a subset of the union.
public export
unionContains : (Ord a, Eq a) => List a -> List a -> Bool
unionContains xs ys = subset (toSet xs) (union' xs ys)

--/ The empty set is a subset of everything.
public export
emptyIsSubset : Eq a => List a -> Bool
emptyIsSubset xs = subset [] xs

-- --- Power set ----------------------------------------------------------------

--/ All subsets of a set.
public export
powerSet : List a -> List (List a)
powerSet [] = [[]]
powerSet (x :: xs) =
  let rest = powerSet xs
  in rest ++ map (x ::) rest

--/ |P(S)| = 2^|S|.
public export
powerSetCardinality : (Ord a, Eq a) => List a -> Bool
powerSetCardinality xs =
  let s = toSet xs
  in length (powerSet s) == power 2 (length s)

--/ Every member of P(S) is a subset of S.
public export
powerSetMembersAreSubsets : (Ord a, Eq a) => List a -> Bool
powerSetMembersAreSubsets xs =
  let s = toSet xs
  in all (\m => subset m s) (powerSet s)

--/ P(S) contains both the empty set and S itself.
public export
powerSetContainsExtremes : (Ord a, Eq a) => List a -> Bool
powerSetContainsExtremes xs =
  let s  = toSet xs
      ps = map toSet (powerSet s)
  in elem [] ps && elem s ps

-- --- Cardinality ---------------------------------------------------------------

--/ Inclusion-exclusion: |A ∪ B| + |A ∩ B| = |A| + |B|.
public export
inclusionExclusion : (Ord a, Eq a) => List a -> List a -> Bool
inclusionExclusion xs ys =
  length (union' xs ys) + length (intersect' xs ys)
    == length (toSet xs) + length (toSet ys)

-- --- Concrete witnesses -------------------------------------------------------
-- Deliberately small: powerSet is exponential, so a 4-element witness already
-- builds 16 subsets and a 10-element one would build 1024.

public export
smallSet : List Int
smallSet = [1, 2, 3]

public export
tinySet : List Int
tinySet = [7, 8]
