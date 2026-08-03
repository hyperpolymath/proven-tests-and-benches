-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.HigherOrder.Identity

import Data.List

-- =============================================================================
-- IDENTITY LAWS
-- =============================================================================
-- Named in the Proven Tests spec (standards
-- .github/ISSUES/cicd-optimization/004-tests-benches-standards.md §3.1) as
-- HigherOrder/Identity.idr.
--
-- These are the standard identity laws of function composition and of the
-- functor/applicative structures Idris2 already provides. They are stated over
-- concrete witnesses rather than universally quantified: this module is the
-- Provisionally-Proven tier, where a property is *checked at run time* on
-- example inputs. A universally quantified statement belongs in the
-- Actually-Proven tier, where it must carry a proof term rather than a Bool.
--
-- That distinction is the whole point of the three-tier ProvenStatus, so it is
-- kept sharp here: nothing in this file claims more than it checks.

-- --- Left and right identity of composition -------------------------------

--/ id . f = f, checked at a point
public export
leftIdentityAt : Eq b => (a -> b) -> a -> Bool
leftIdentityAt f x = (id . f) x == f x

--/ f . id = f, checked at a point
public export
rightIdentityAt : Eq b => (a -> b) -> a -> Bool
rightIdentityAt f x = (f . id) x == f x

--/ Both identity laws at one point
public export
identityBothSidesAt : Eq b => (a -> b) -> a -> Bool
identityBothSidesAt f x = leftIdentityAt f x && rightIdentityAt f x

-- --- Identity is idempotent under composition ------------------------------

--/ id . id = id
public export
identityIdempotentAt : Eq a => a -> Bool
identityIdempotentAt x = (Prelude.id . Prelude.id) x == Prelude.id x

-- --- Functor identity law ---------------------------------------------------

--/ map id = id, for List
public export
functorIdentityList : Eq a => List a -> Bool
functorIdentityList xs = map Prelude.id xs == xs

--/ map id = id, for Maybe
public export
functorIdentityMaybe : Eq a => Maybe a -> Bool
functorIdentityMaybe mx = map Prelude.id mx == mx

-- --- Composition law (the companion to identity) ----------------------------

--/ map (g . f) = map g . map f, for List
public export
functorCompositionList : Eq c => (b -> c) -> (a -> b) -> List a -> Bool
functorCompositionList g f xs = map (g . f) xs == (map g . map f) xs

-- --- Concrete witnesses used by the test suite ------------------------------

public export
exampleInts : List Int
exampleInts = [1, 2, 3, 5, 8, 13]

public export
exampleIncrement : Int -> Int
exampleIncrement n = n + 1

public export
exampleDouble : Int -> Int
exampleDouble n = n * 2
