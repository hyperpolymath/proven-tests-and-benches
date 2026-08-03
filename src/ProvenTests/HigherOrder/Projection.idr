-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.HigherOrder.Projection

import Data.List

-- =============================================================================
-- PROJECTION LAWS
-- =============================================================================
-- Spec: HigherOrder/Projection.idr.
--
-- A projection discards information and is therefore idempotent: applying it
-- twice tells you nothing more than applying it once. These are the get/put
-- laws a lens must satisfy, stated over concrete witnesses (the
-- Provisionally-Proven tier — see HigherOrder/Identity.idr for why that
-- distinction is kept explicit).

-- --- A minimal lens ---------------------------------------------------------

public export
record Lens s a where
  constructor MkLens
  get : s -> a
  put : a -> s -> s

-- --- The three lens laws ----------------------------------------------------

--/ get-put: putting back what you got changes nothing.
public export
getPutAt : Eq s => Lens s a -> s -> Bool
getPutAt l s = put l (get l s) s == s

--/ put-get: getting what you just put returns it.
public export
putGetAt : Eq a => Lens s a -> a -> s -> Bool
putGetAt l a s = get l (put l a s) == a

--/ put-put: the last put wins.
public export
putPutAt : Eq s => Lens s a -> a -> a -> s -> Bool
putPutAt l a1 a2 s = put l a2 (put l a1 s) == put l a2 s

--/ All three laws at one point.
public export
lensLawsAt : (Eq s, Eq a) => Lens s a -> a -> a -> s -> Bool
lensLawsAt l a1 a2 s =
  getPutAt l s && putGetAt l a1 s && putPutAt l a1 a2 s

-- --- Projection idempotence -------------------------------------------------

--/ A projection p satisfies p . p = p.
public export
projectionIdempotentAt : Eq a => (a -> a) -> a -> Bool
projectionIdempotentAt p x = p (p x) == p x

-- --- Concrete witnesses -----------------------------------------------------

public export
record Point where
  constructor MkPoint
  px : Int
  py : Int

public export
Eq Point where
  (MkPoint a b) == (MkPoint c d) = a == c && b == d

--/ The x-coordinate lens.
public export
xLens : Lens Point Int
xLens = MkLens px (\v, p => MkPoint v (py p))

--/ Projecting onto the x-axis: sets y to 0. Idempotent.
public export
ontoXAxis : Point -> Point
ontoXAxis (MkPoint x _) = MkPoint x 0

public export
examplePoint : Point
examplePoint = MkPoint 3 4
