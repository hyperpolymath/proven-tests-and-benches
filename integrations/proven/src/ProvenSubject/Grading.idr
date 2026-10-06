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

provenCert : String -> TypeSafetyCertificate
provenCert name = typeSafetyCert 6 "Idris2 dependent types" "proven MODULE-STATUS + STATE.a2ml" [name]

provenFramework : FrameworkSafetyProof
provenFramework =
  frameworkProof "proven (Idris2 --total safe wrappers)"
    (typeSafetyCert 6 "Idris2" "proven --total" ["totality-checked"])
    (typeSafetyCert 6 "Idris2" "proven --total" ["Maybe/Either safe API"])
    "proven MODULE-STATUS.txt"

--/ The grade a module receives, and why.
--/
--/ `claimed` is the tier the reading assigns from proven's OWN ledgers.
--/ `baton` carries the evidence-carrying provenance actually HELD in this
--/ build. Actually-Proven provenance needs a typechecked proof term
--/ (`Witnessed`), and proven's proofs live in another repository and are not
--/ re-checked here, so the held provenance of an external module is at most
--/ Provisionally-Proven: an Actually-Proven claim is counted, not certified.
public export
record Graded where
  constructor MkGraded
  modName    : String
  tier       : Tier
  claimed    : ProvenStatus
  baton      : BatonSpec
  rationale  : String

--/ The tier this reading claims for the module (from proven's own ledgers).
public export
statusOfGraded : Graded -> ProvenStatus
statusOfGraded = claimed

--/ The tier of the evidence this build actually holds for the module.
public export
heldHere : Graded -> ProvenStatus
heldHere = batonStatus . baton

-- External attestation: proven says so, this build has not re-checked it.
attested : String -> Provenance
attested nm = PProvisionallyProven (MkProvisionalEvidence provenFramework (provenCert nm))

-- as-declared provenance
declaredProvenance : ModuleStatus -> Provenance
declaredProvenance ms = case tier ms of
  FirstClass  => attested (name ms)
  SecondClass => attested (name ms)
  Wip         => PUnproven

-- as-declared claim: the MODULE-STATUS tier verbatim
declaredClaim : Tier -> ProvenStatus
declaredClaim FirstClass  = ActuallyProven
declaredClaim SecondClass = ProvisionallyProven
declaredClaim Wip         = Unproven

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
           then MkGraded nm FirstClass ActuallyProven
                  (MkBatonSpec coord (attested nm) cost)
                  ("Actually-Proven (claimed): FIRST-CLASS, " ++ show prf
                    ++ " proofs, in clean set; held here as Provisionally - not re-checked in this build")
           else MkGraded nm FirstClass ProvisionallyProven
                  (MkBatonSpec coord
                    (PProvisionallyProven (MkProvisionalEvidence provenFramework (provenCert nm)))
                    (Fin 15))
                  ("CAPPED to Provisionally: FIRST-CLASS with " ++ show prf
                    ++ " proofs but NOT in the zero-OWED clean set (sits in the OWED ledger)")
       SecondClass =>
         MkGraded nm SecondClass ProvisionallyProven
           (MkBatonSpec coord
             (PProvisionallyProven (MkProvisionalEvidence provenFramework (provenCert nm))) cost)
           ("Provisionally-Proven: SECOND-CLASS safe wrapper (--total, no deep proofs)"
             ++ (if clean then "; clean (zero OWED)" else ""))
       Wip =>
         MkGraded nm Wip Unproven (MkBatonSpec coord PUnproven cost)
           "Unproven: WIP — does not compile"

--/ Grade one module under the AS-DECLARED reading (trust the tier verbatim).
public export
gradeDeclared : ModuleStatus -> Graded
gradeDeclared ms =
  let coord = tierCoord (tier ms)
      cost  = tierCost (tier ms) (fromMaybe 0 (proofs ms))
  in MkGraded (name ms) (tier ms) (declaredClaim (tier ms))
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
