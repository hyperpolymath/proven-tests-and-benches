-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.AffineScript.Affinity

import Data.List

-- =============================================================================
-- AFFINITY: NO USE AFTER MOVE
-- =============================================================================
-- Models the first of the three guarantees stated in the AffineScript borrow
-- checker (`affinescript/lib/borrow.ml`, module docstring):
--
--     - No use after move
--     - No conflicting borrows
--     - Borrows don't outlive owners
--
-- This module covers the first. Borrow.idr covers the other two.
--
-- IMPORTANT — what this is and is not. These are properties of a *model* of
-- affinity written here, checked on named witnesses. They are NOT a proof about
-- the OCaml implementation in lib/borrow.ml, and passing them says nothing
-- about whether that implementation is correct. They pin down what the
-- guarantee MEANS precisely enough to disagree with, which is the useful first
-- step and the honest limit of the Provisionally-Proven tier.
--
-- An affine value may be used AT MOST once: zero uses is fine (a value may be
-- dropped), two or more is not. That is the difference from a linear value,
-- which must be used exactly once.

-- --- The model ---------------------------------------------------------------

public export
Var : Type
Var = String

--/ A use-site trace: the sequence of variable uses in evaluation order.
public export
Trace : Type
Trace = List Var

--/ How many times a variable is used in a trace.
public export
useCount : Var -> Trace -> Nat
useCount v t = length (filter (== v) t)

--/ Affine: used at most once.
public export
affine : Var -> Trace -> Bool
affine v t = useCount v t <= 1

--/ Linear: used exactly once. Stated for contrast — AffineScript is affine,
--/ not linear, and conflating the two is the usual mistake.
public export
linear : Var -> Trace -> Bool
linear v t = useCount v t == 1

--/ Every variable in the trace is affine.
public export
traceIsAffine : Trace -> Bool
traceIsAffine t = all (\v => affine v t) (nub t)

-- --- Moves --------------------------------------------------------------------

--/ A move consumes the source. After `move x y`, x must not be used again.
public export
data Event : Type where
  Use  : Var -> Event
  Move : Var -> Var -> Event   -- move from, to

--/ Variables that have been moved out of, at each point.
public export
movedOut : List Event -> List Var
movedOut [] = []
movedOut (Use _ :: es) = movedOut es
movedOut (Move from _ :: es) = from :: movedOut es

--/ No use after move: no Use of a variable that an EARLIER event moved out of.
public export
noUseAfterMove : List Event -> Bool
noUseAfterMove es = go [] es
  where
    go : List Var -> List Event -> Bool
    go _ [] = True
    go moved (Use v :: rest) =
      if elem v moved then False else go moved rest
    go moved (Move from to :: rest) = go (from :: moved) rest

-- --- Properties ---------------------------------------------------------------

--/ Dropping a value without using it is affine (0 uses <= 1).
public export
dropIsAffine : Var -> Bool
dropIsAffine v = affine v []

--/ Using once is affine.
public export
singleUseIsAffine : Var -> Bool
singleUseIsAffine v = affine v [v]

--/ Using twice is NOT affine. Stated positively so a passing test means the
--/ violation was detected, not that nothing happened.
public export
doubleUseIsRejected : Var -> Bool
doubleUseIsRejected v = not (affine v [v, v])

--/ Affinity is weaker than linearity: dropping satisfies affine but not linear.
public export
affineIsWeakerThanLinear : Var -> Bool
affineIsWeakerThanLinear v = affine v [] && not (linear v [])

--/ A move followed by a use of the source is rejected.
public export
useAfterMoveIsRejected : Var -> Var -> Bool
useAfterMoveIsRejected x y = not (noUseAfterMove [Move x y, Use x])

--/ A move followed by a use of the DESTINATION is fine.
public export
useOfMoveTargetIsAllowed : Var -> Var -> Bool
useOfMoveTargetIsAllowed x y = noUseAfterMove [Move x y, Use y]

--/ Use before move is fine — order matters.
public export
useBeforeMoveIsAllowed : Var -> Var -> Bool
useBeforeMoveIsAllowed x y = noUseAfterMove [Use x, Move x y]

-- --- Concrete witnesses -------------------------------------------------------

public export
varX : Var
varX = "x"

public export
varY : Var
varY = "y"

public export
exampleGoodTrace : Trace
exampleGoodTrace = ["a", "b", "c"]

public export
exampleBadTrace : Trace
exampleBadTrace = ["a", "b", "a"]
