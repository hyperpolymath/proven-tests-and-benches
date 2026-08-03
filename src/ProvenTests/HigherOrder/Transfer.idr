-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.HigherOrder.Transfer

import Data.List

-- =============================================================================
-- TRANSFER LAWS
-- =============================================================================
-- Spec: HigherOrder/Transfer.idr, described there as "interdimensional
-- transfer".
--
-- The spec gives no formal definition of that phrase, so this module does NOT
-- attempt to encode one. What it encodes instead is the well-defined notion
-- transfer rests on either way: a structure-preserving map between two
-- representations, and the round-trip laws that make such a map trustworthy.
--
-- If "interdimensional transfer" later acquires a precise meaning, this module
-- is where it belongs, and these laws are the floor it has to clear.

-- --- A transfer between two representations ---------------------------------

public export
record Transfer a b where
  constructor MkTransfer
  forward  : a -> b
  backward : b -> a

-- --- Round-trip laws --------------------------------------------------------

--/ Round-tripping a value returns it: backward . forward = id.
--/ This is the law that makes a transfer lossless.
public export
roundTripAt : Eq a => Transfer a b -> a -> Bool
roundTripAt t x = backward t (forward t x) == x

--/ The reverse round trip. A transfer satisfying BOTH is an isomorphism;
--/ one satisfying only `roundTripAt` is a section/retraction pair, which is
--/ the common case when b carries more structure than a.
public export
reverseRoundTripAt : Eq b => Transfer a b -> b -> Bool
reverseRoundTripAt t y = forward t (backward t y) == y

--/ Both directions: an isomorphism at a point.
public export
isomorphismAt : (Eq a, Eq b) => Transfer a b -> a -> b -> Bool
isomorphismAt t x y = roundTripAt t x && reverseRoundTripAt t y

-- --- Composition -------------------------------------------------------------

--/ Transfers compose, and the composite's forward is the composite of forwards.
public export
composeTransfer : Transfer a b -> Transfer b c -> Transfer a c
composeTransfer t u =
  MkTransfer (forward u . forward t) (backward t . backward u)

--/ Composing with the identity transfer changes nothing.
public export
identityTransfer : Transfer a a
identityTransfer = MkTransfer id id

public export
composeIdentityAt : Eq b => Transfer a b -> a -> Bool
composeIdentityAt t x =
  forward (composeTransfer identityTransfer t) x == forward t x

-- --- Structure preservation --------------------------------------------------

--/ A transfer applied elementwise preserves list length.
public export
transferPreservesLength : Transfer a b -> List a -> Bool
transferPreservesLength t xs = length (map (forward t) xs) == length xs

-- --- Concrete witnesses -----------------------------------------------------

--/ Int <-> String is a section/retraction, not an isomorphism: "007" and "7"
--/ both go to 7, so the reverse round trip fails. Included deliberately — the
--/ suite asserts the direction that holds and does not claim the one that
--/ does not.
public export
intStringTransfer : Transfer Int String
intStringTransfer = MkTransfer show (\s => cast s)

--/ A genuine isomorphism: negation is its own inverse.
public export
negateTransfer : Transfer Int Int
negateTransfer = MkTransfer negate negate

public export
exampleInts : List Int
exampleInts = [0, 1, -1, 42, -99]
