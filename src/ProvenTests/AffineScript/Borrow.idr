-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.AffineScript.Borrow

import Data.List

-- =============================================================================
-- BORROWING: NO CONFLICTING BORROWS, NO ESCAPING BORROWS
-- =============================================================================
-- Models guarantees two and three of the AffineScript borrow checker
-- (`affinescript/lib/borrow.ml`):
--
--     - No conflicting borrows
--     - Borrows don't outlive owners
--
-- The two borrow kinds are taken from that module's `borrow_kind`:
--
--     Shared     (* Immutable borrow (&) *)
--     Exclusive  (* Mutable borrow (&mut) *)
--
-- As in Affinity.idr, these are properties of a model written here, checked on
-- named witnesses. They are not a proof about the OCaml implementation.

-- --- The model ---------------------------------------------------------------

public export
Var : Type
Var = String

public export
data BorrowKind : Type where
  Shared    : BorrowKind
  Exclusive : BorrowKind

public export
Eq BorrowKind where
  Shared    == Shared    = True
  Exclusive == Exclusive = True
  _         == _         = False

public export
Show BorrowKind where
  show Shared    = "shared"
  show Exclusive = "exclusive"

--/ A borrow of a place, live over a half-open scope [start, end).
public export
record Borrow where
  constructor MkBorrow
  place : Var
  kind  : BorrowKind
  start : Nat
  end   : Nat

--/ Is the borrow live at time t?
public export
liveAt : Borrow -> Nat -> Bool
liveAt b t = b.start <= t && t < b.end

--/ Do two borrows overlap in time?
public export
overlaps : Borrow -> Borrow -> Bool
overlaps a b = a.start < b.end && b.start < a.end

-- --- Guarantee 2: no conflicting borrows --------------------------------------
--
-- Shared XOR Exclusive: any number of shared borrows may coexist, but an
-- exclusive borrow excludes every other borrow of the same place.

--/ Two borrows conflict when they touch the same place, overlap in time, and
--/ at least one is exclusive.
public export
conflicts : Borrow -> Borrow -> Bool
conflicts a b =
  a.place == b.place
    && overlaps a b
    && (a.kind == Exclusive || b.kind == Exclusive)

--/ A set of borrows is well-formed when no two conflict.
public export
noConflicts : List Borrow -> Bool
noConflicts bs =
  all (\(x, y) => not (conflicts x y)) (distinctPairs bs)
  where
    distinctPairs : List Borrow -> List (Borrow, Borrow)
    distinctPairs [] = []
    distinctPairs (x :: xs) = map (\y => (x, y)) xs ++ distinctPairs xs

-- --- Guarantee 3: borrows don't outlive owners ---------------------------------

--/ An owner, live over [start, end).
public export
record Owner where
  constructor MkOwner
  name  : Var
  start : Nat
  end   : Nat

--/ A borrow is contained by its owner's lifetime.
public export
containedBy : Borrow -> Owner -> Bool
containedBy b o =
  b.place == o.name && o.start <= b.start && b.end <= o.end

--/ Every borrow of the owner is contained by it.
public export
noEscapingBorrows : Owner -> List Borrow -> Bool
noEscapingBorrows o bs =
  all (\b => if b.place == o.name then containedBy b o else True) bs

-- --- Properties ----------------------------------------------------------------

public export
sharedBorrowsCoexist : Bool
sharedBorrowsCoexist =
  noConflicts [ MkBorrow "v" Shared 0 10, MkBorrow "v" Shared 2 8 ]

public export
exclusiveExcludesShared : Bool
exclusiveExcludesShared =
  not (noConflicts [ MkBorrow "v" Exclusive 0 10, MkBorrow "v" Shared 2 8 ])

public export
twoExclusivesConflict : Bool
twoExclusivesConflict =
  not (noConflicts [ MkBorrow "v" Exclusive 0 10, MkBorrow "v" Exclusive 2 8 ])

--/ Different places never conflict, whatever the kinds.
public export
differentPlacesDoNotConflict : Bool
differentPlacesDoNotConflict =
  noConflicts [ MkBorrow "v" Exclusive 0 10, MkBorrow "w" Exclusive 0 10 ]

--/ Disjoint lifetimes never conflict, even exclusive on the same place.
public export
disjointLifetimesDoNotConflict : Bool
disjointLifetimesDoNotConflict =
  noConflicts [ MkBorrow "v" Exclusive 0 5, MkBorrow "v" Exclusive 5 10 ]

--/ Conflict is symmetric.
public export
conflictSymmetric : Borrow -> Borrow -> Bool
conflictSymmetric a b = conflicts a b == conflicts b a

--/ A borrow inside its owner's lifetime is contained.
public export
containedBorrowAccepted : Bool
containedBorrowAccepted =
  noEscapingBorrows (MkOwner "v" 0 10) [ MkBorrow "v" Shared 2 8 ]

--/ A borrow outliving its owner is rejected.
public export
escapingBorrowRejected : Bool
escapingBorrowRejected =
  not (noEscapingBorrows (MkOwner "v" 0 10) [ MkBorrow "v" Shared 2 12 ])

--/ A borrow starting before its owner is rejected.
public export
earlyBorrowRejected : Bool
earlyBorrowRejected =
  not (noEscapingBorrows (MkOwner "v" 5 10) [ MkBorrow "v" Shared 0 8 ])

-- --- Concrete witnesses --------------------------------------------------------

public export
sharedA : Borrow
sharedA = MkBorrow "v" Shared 0 10

public export
exclusiveB : Borrow
exclusiveB = MkBorrow "v" Exclusive 2 8
