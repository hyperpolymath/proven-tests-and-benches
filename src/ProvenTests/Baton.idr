-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Baton

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import ProvenTests.Tropical
import Data.List1

%default total

-- =============================================================================
-- THE CROSS-REPO BATON CONTRACT
-- =============================================================================
-- The proven-tests-side schema a bag-of-actions Baton carries so the mesh can:
--   * schedule Zigzag-lattice coverage          → `coord`
--   * route by tropical cost (cheapest = ⊕ min) → `cost`  (ProvenTests.Tropical)
--   * carry provenance *with its evidence*      → `provenance` (ProvenTests.Types)
--
-- Because `provenance` is the evidence-carrying `Provenance` type, an
-- Actually-/Provisionally-Proven Baton is unrepresentable without its proof —
-- the honesty invariant survives the trip across the mesh.

public export
record BatonSpec where
  constructor MkBatonSpec
  coord      : ZigzagCoord
  provenance : Provenance
  cost       : ExtNat

public export
Show BatonSpec where
  show b =
    show (coord b) ++ " [" ++ show (statusOf (provenance b))
    ++ ", cost=" ++ show (cost b) ++ "]"

--/ The bare provenance tag a Baton currently carries.
public export
batonStatus : BatonSpec -> ProvenStatus
batonStatus = statusOf . provenance

--/ Route to the cheaper Baton — the planner's tropical-min decision (⊕ on cost).
public export
cheaperBaton : BatonSpec -> BatonSpec -> BatonSpec
cheaperBaton x y = if lteEN (cost x) (cost y) then x else y

-- =============================================================================
-- THE TROPICAL LAWS AS AN ACTUALLY-PROVEN TEST
-- =============================================================================
-- The laws in ProvenTests.Tropical are total, machine-checked proofs. If this
-- package compiles, they hold for every input — so this classification is
-- genuinely Actually-Proven (its proof ladder cites the checked theorems by
-- name). This is the first cell of the lattice to reach the top provenance tier
-- on real evidence rather than sampling.

tropicalFile : Maybe String
tropicalFile = Just "src/ProvenTests/Tropical.idr"

public export
tropicalLawsClassification : TestMetadata
tropicalLawsClassification =
  let tid    = MkTestId "ProvenTests.Tropical" "semiringLaws" 0
      ladder = MkProofStep "min-plus (+) is commutative"      tropicalFile Nothing (Just "oplusComm")
           ::: [ MkProofStep "(+) is associative"             tropicalFile Nothing (Just "oplusAssoc")
               , MkProofStep "(+) is idempotent"              tropicalFile Nothing (Just "oplusIdem")
               , MkProofStep "PosInf is the (+) identity"     tropicalFile Nothing (Just "oplusIdentityR")
               , MkProofStep "Fin 0 is the (*) identity"      tropicalFile Nothing (Just "otimesIdentityR")
               , MkProofStep "(*) is commutative"             tropicalFile Nothing (Just "otimesComm") ]
      design = MkDesignSafetyProof
                 "Tropical (min-plus) semiring over Nat union {PosInf}"
                 "Total, machine-checked Idris2 equality proofs"
                 ["(+) comm/assoc/idem/identity", "(*) comm/identity"]
                 ["carrier is Nat union {PosInf}; Double-valued resource bounds are a separate sampled tier"]
      cert   = MkTypeSafetyCertificate 6 "Idris2 dependent types" "idris2 --build (total proofs)"
                 ["Tropical semiring laws"]
  in classifyActuallyProven tid "Tropical semiring laws (machine-checked)" ladder design cert

--/ Runtime spot-check of the operations. The compile-time proofs are the real
--/ evidence; this also exercises concrete values (and is what the runner asserts).
public export
tropicalLawsHold : Bool
tropicalLawsHold =
  (oplus (Fin 3) (Fin 5) == Fin 3) &&
  (oplus (Fin 7) PosInf == Fin 7) &&
  (oplus PosInf (Fin 2) == Fin 2) &&
  (otimes (Fin 4) (Fin 0) == Fin 4) &&
  (cheapest (Fin 9 ::: [Fin 2, Fin 5, PosInf]) == Fin 2)

--/ Demonstrate the Baton contract: route by tropical cost, carry provenance.
--/ Exercises BatonSpec/cheaperBaton so the bridge type is tested, not decorative.
public export
batonContractHolds : Bool
batonContractHolds =
  let coord = MkCoord CoEvaluation Collective EndToEnd Dependability
      cheap = MkBatonSpec coord PUnproven (Fin 2)
      dear  = MkBatonSpec coord PUnproven (Fin 9)
      routed = cheaperBaton cheap dear
  in (cost routed == Fin 2) && (batonStatus routed == Unproven)
