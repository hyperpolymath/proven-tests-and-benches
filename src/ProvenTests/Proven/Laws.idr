-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Proven.Laws

import Data.List
import Data.Nat

%default total

-- =============================================================================
-- ACTUALLY-PROVEN LAWS
-- =============================================================================
-- Everything in this module is a THEOREM: a statement quantified over all
-- inputs, with a term inhabiting it, checked by the Idris2 typechecker.
--
-- This is the difference the three-tier ProvenStatus exists to express, and
-- until now nothing in the repo was on this side of it:
--
--   Provisionally-Proven   prop : Widget -> Bool          checked on witnesses
--   Actually-Proven        prop : (w : Widget) -> P w     holds for ALL inputs
--
-- `%default total` is not decoration. Without it a proof could be inhabited by
-- a non-terminating term and Idris2 would accept it, which would make every
-- claim below worthless. Totality is what makes these proofs mean something.
--
-- NOTE ON ProofStep: the ladder passed to `provenTest` is METADATA — a
-- description, file, line and theorem name. It does not carry the proof. The
-- proof is here, and it is the typechecker accepting this file that
-- establishes it. A ProofStep pointing at a theorem that does not exist would
-- be a lie the framework cannot catch, so every ladder entry in
-- tests/ProvenLawsTests/ names a function defined in this file.

-- --- Identity laws ------------------------------------------------------------

--/ THEOREM: id . f = f, at every point.
--/ Holds definitionally: (id . f) x reduces to f x.
public export
leftIdentityProof : (f : a -> b) -> (x : a) -> (Prelude.id . f) x = f x
leftIdentityProof _ _ = Refl

--/ THEOREM: f . id = f, at every point.
public export
rightIdentityProof : (f : a -> b) -> (x : a) -> (f . Prelude.id) x = f x
rightIdentityProof _ _ = Refl

--/ THEOREM: id is idempotent under composition.
public export
identityIdempotentProof : (x : a) -> (Prelude.id . Prelude.id) x = Prelude.id x
identityIdempotentProof _ = Refl

-- --- Functor laws for List -----------------------------------------------------

--/ THEOREM: map id = id, for every list.
--/ Proved by induction on the list. The nil case is definitional; the cons case
--/ rewrites by the inductive hypothesis.
public export
mapIdentityProof : (xs : List a) -> map Prelude.id xs = xs
mapIdentityProof [] = Refl
mapIdentityProof (x :: xs) = rewrite mapIdentityProof xs in Refl

--/ THEOREM: map fuses. map g (map f xs) = map (g . f) xs, for every list.
public export
mapFusionProof : (g : b -> c) -> (f : a -> b) -> (xs : List a) ->
                 map g (map f xs) = map (g . f) xs
mapFusionProof _ _ [] = Refl
mapFusionProof g f (x :: xs) = rewrite mapFusionProof g f xs in Refl

--/ THEOREM: map preserves length, for every list.
public export
mapLengthProof : (f : a -> b) -> (xs : List a) -> length (map f xs) = length xs
mapLengthProof _ [] = Refl
mapLengthProof f (x :: xs) = rewrite mapLengthProof f xs in Refl

-- --- Functor law for Maybe -----------------------------------------------------

--/ THEOREM: map id = id, for Maybe. Both cases are definitional.
public export
mapMaybeIdentityProof : (mx : Maybe a) -> map Prelude.id mx = mx
mapMaybeIdentityProof Nothing  = Refl
mapMaybeIdentityProof (Just _) = Refl

-- --- Append laws ---------------------------------------------------------------

--/ THEOREM: [] is a right unit for ++.
--/ The left unit is definitional; this direction needs induction.
public export
appendNilRightProof : (xs : List a) -> xs ++ [] = xs
appendNilRightProof [] = Refl
appendNilRightProof (x :: xs) = rewrite appendNilRightProof xs in Refl

--/ THEOREM: length distributes over ++.
public export
appendLengthProof : (xs : List a) -> (ys : List a) ->
                    length (xs ++ ys) = length xs + length ys
appendLengthProof [] ys = Refl
appendLengthProof (x :: xs) ys = rewrite appendLengthProof xs ys in Refl

-- --- Reverse ------------------------------------------------------------------

--/ THEOREM: reversing a singleton is itself.
public export
reverseSingletonProof : (x : a) -> reverse [x] = [x]
reverseSingletonProof _ = Refl

-- --- Affinity (the AffineScript guarantee, proved rather than sampled) ---------
--
-- Affinity.idr checks `affine v t = useCount v t <= 1` on named witnesses.
-- These are the same statements quantified over ALL variables.

--/ THEOREM: a variable used in no trace has use-count zero.
--/ This is the "dropping is affine" case, for every variable rather than for
--/ the one witness AffinityTests uses.
public export
emptyTraceUseCountProof : (v : String) -> length (filter (== v) []) = 0
emptyTraceUseCountProof _ = Refl

--/ THEOREM: filtering a list never lengthens it.
--/ The bound that makes affinity checkable: a use-count can never exceed the
--/ length of the trace it is counted from.
public export
filterLengthBoundProof : (p : a -> Bool) -> (xs : List a) ->
                         LTE (length (filter p xs)) (length xs)
filterLengthBoundProof _ [] = LTEZero
filterLengthBoundProof p (x :: xs) with (p x)
  _ | True  = LTESucc (filterLengthBoundProof p xs)
  _ | False = lteSuccRight (filterLengthBoundProof p xs)
