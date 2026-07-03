-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.Grading

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Zigzag
import ProvenTests.Tropical
import ProvenTests.Baton
import ProvenSubject.Ledger
import Data.List
import Data.List1
import Data.Maybe

%default total

-- =============================================================================
-- GRADING proven's modules into the three-tier provenance model
-- =============================================================================
-- This is the moment the framework grades a REAL subject. Each proven module
-- becomes a typed BatonSpec whose provenance is evidence-carrying — so a
-- module cannot be reported Actually-Proven without a proof ladder.
--
-- Two readings, and the GAP between them is the interesting number:
--
--   * as-declared  — trust MODULE-STATUS.txt's tier verbatim
--                    (FIRST-CLASS => Actually, SECOND => Provisionally, WIP => Unproven)
--   * strict       — evidence-carrying: Actually-Proven requires BOTH a proof
--                    count > 0 AND membership in proven's zero-OWED clean set.
--                    A module that carries proofs but still sits in the 256-axiom
--                    OWED ledger is capped at Provisionally-Proven.
--
-- Under the strict reading, proven's proof-bearing modules (Core, SafeAttestation,
-- SafeOrdering, SafeTrust) and its clean modules (SafeChecksum, ...) are DISJOINT,
-- so the strict Actually-Proven count is 0 — the mechanized drift finding.

-- Cost model: cheaper = closer to done. WIP is most expensive to trust.
tierCost : Tier -> Nat -> ExtNat
tierCost FirstClass  prf = Fin (minus 10 (min 10 prf))   -- more proofs => cheaper
tierCost SecondClass _   = Fin 20
tierCost Wip         _   = PosInf                          -- untrustworthy: infinite

-- A coordinate per tier, so the graded modules land on the lattice sensibly.
tierCoord : Tier -> ZigzagCoord
tierCoord FirstClass  = MkCoord CoEvaluation Thing ProofRegressionTest Dependability
tierCoord SecondClass = MkCoord CoImplementation Collective ContractInvariantTest Safety
tierCoord Wip         = MkCoord CoConception Human BuildTest Maintainability

subjectFile : String -> Maybe String
subjectFile name = Just ("proven: src/Proven/" ++ name ++ ".idr")

-- Build a proof ladder for a genuinely Actually-Proven module from its proof
-- count (we cite the module's own Proofs.idr; proven's ledger is the evidence).
provenLadder : String -> Nat -> List1 ProofStep
provenLadder name prf =
  MkProofStep
    (name ++ ": " ++ show prf ++ " discharged proofs, zero outstanding OWED axioms")
    (subjectFile name) Nothing (Just (name ++ ".Proofs"))
  ::: []

provenDesign : String -> DesignSafetyProof
provenDesign name =
  MkDesignSafetyProof
    (name ++ " — proven module graded from its own ledgers")
    "Idris2 --total + discharged Proofs.idr (clean: zero OWED)"
    ["dependent-type proofs"] ["graded from proven's self-audit; proofs not re-checked here"]

provenCert : String -> TypeSafetyCertificate
provenCert name = typeSafetyCert 6 "Idris2 dependent types" "proven MODULE-STATUS + STATE.a2ml" [name]

provenFramework : FrameworkSafetyProof
provenFramework =
  frameworkProof "proven (Idris2 --total safe wrappers)"
    (typeSafetyCert 6 "Idris2" "proven --total" ["totality-checked"])
    (typeSafetyCert 6 "Idris2" "proven --total" ["Maybe/Either safe API"])
    "proven MODULE-STATUS.txt"

--/ The grade a module receives, and why.
public export
record Graded where
  constructor MkGraded
  modName    : String
  tier       : Tier
  baton      : BatonSpec
  rationale  : String

public export
statusOfGraded : Graded -> ProvenStatus
statusOfGraded = batonStatus . baton

-- as-declared provenance
declaredProvenance : ModuleStatus -> Provenance
declaredProvenance ms = case tier ms of
  FirstClass  =>
    PActuallyProven (MkActualEvidence
      (provenLadder (name ms) (fromMaybe 0 (proofs ms)))
      (provenDesign (name ms)) (provenCert (name ms)))
  SecondClass => PProvisionallyProven (MkProvisionalEvidence provenFramework (provenCert (name ms)))
  Wip         => PUnproven

--/ Grade one module under the STRICT (evidence-carrying) reading.
public export
gradeStrict : OwedLedger -> ModuleStatus -> Graded
gradeStrict led ms =
  let nm   = name ms
      prf  = fromMaybe 0 (proofs ms)
      clean = isClean led nm
      cost = tierCost (tier ms) prf
      coord = tierCoord (tier ms)
  in case tier ms of
       FirstClass =>
         if clean && prf > 0
           then MkGraded nm FirstClass
                  (MkBatonSpec coord
                    (PActuallyProven (MkActualEvidence (provenLadder nm prf)
                       (provenDesign nm) (provenCert nm))) cost)
                  ("Actually-Proven: FIRST-CLASS, " ++ show prf ++ " proofs, in clean set")
           else MkGraded nm FirstClass
                  (MkBatonSpec coord
                    (PProvisionallyProven (MkProvisionalEvidence provenFramework (provenCert nm)))
                    (Fin 15))
                  ("CAPPED to Provisionally: FIRST-CLASS with " ++ show prf
                    ++ " proofs but NOT in the zero-OWED clean set (sits in the OWED ledger)")
       SecondClass =>
         MkGraded nm SecondClass
           (MkBatonSpec coord
             (PProvisionallyProven (MkProvisionalEvidence provenFramework (provenCert nm))) cost)
           ("Provisionally-Proven: SECOND-CLASS safe wrapper (--total, no deep proofs)"
             ++ (if clean then "; clean (zero OWED)" else ""))
       Wip =>
         MkGraded nm Wip (MkBatonSpec coord PUnproven cost)
           "Unproven: WIP — does not compile"

--/ Grade one module under the AS-DECLARED reading (trust the tier verbatim).
public export
gradeDeclared : ModuleStatus -> Graded
gradeDeclared ms =
  let coord = tierCoord (tier ms)
      cost  = tierCost (tier ms) (fromMaybe 0 (proofs ms))
  in MkGraded (name ms) (tier ms)
       (MkBatonSpec coord (declaredProvenance ms) cost)
       ("As declared: " ++ show (tier ms))

-- ── summary counts ───────────────────────────────────────────────────────────

public export
record TierCounts where
  constructor MkTierCounts
  actually      : Nat
  provisionally : Nat
  unproven      : Nat

public export
Show TierCounts where
  show c = show (actually c) ++ " Actually / "
        ++ show (provisionally c) ++ " Provisionally / "
        ++ show (unproven c) ++ " Unproven"

public export
countTiers : List Graded -> TierCounts
countTiers = foldl bump (MkTierCounts 0 0 0)
  where
    bump : TierCounts -> Graded -> TierCounts
    bump c g = case statusOfGraded g of
      ActuallyProven      => { actually      $= S } c
      ProvisionallyProven => { provisionally $= S } c
      Unproven            => { unproven      $= S } c
