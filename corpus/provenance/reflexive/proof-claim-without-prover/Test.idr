-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

||| Corpus unit: proof-claim-without-prover
||| (battery: provenance, category: reflexive)
|||
||| Ground truth (the defect class hyperpolymath/standards' SPARK Theatre
||| Gate exists to fail, and the subject of hyperpolymath/standards#692 for
||| Rust/Creusot): a repository whose README, badge or manifest says
||| "formally verified with SPARK" / "verified with Creusot" while no prover
||| runs anywhere in its CI, or runs over zero obligations. The banner is the
||| whole of the evidence. A verification gate that accepts the claim without
||| a prover event behind it reports assurance that nothing produced —
||| proof theatre.
|||
||| The checker inspects a verification report — one line per prover naming
||| whether the tree CLAIMS verification by it, whether the prover RAN, and
||| whether it discharged any obligations — plus the verdict the gate claimed,
||| and FIRES when the report claims PASS while some prover is claimed but
||| either did not run or ran over no obligations. A prover that ran with
||| obligations and is not claimed is unadvertised proof, not theatre, and
||| never fires.
|||
||| Exit convention (docs/TEST-DOCTRINE.adoc — outcomes are 0/1/2):
|||   0 = check ran, report consistent            (SILENT)
|||   1 = check ran, defect present               (FIRED:
|||         proof-claim-without-prover)
|||   2 = NO CHECK WAS PERFORMED                  (unreadable, unparseable, or
|||         incomplete fixture — a crash or an empty payload is never silence)
module Test

import Data.String
import System
import System.File

%default total

-- =============================================================================
-- REPORT GRAMMAR
-- =============================================================================
-- One prover per line, one verdict line last, nothing else:
--   prover <name> claimed <yes|no> ran <yes|no> obligations <some|none>
--   verdict <PASS|FAIL>
-- `claimed` = the tree advertises verification by this prover (README banner,
-- badge, manifest field); `ran` = a prover job executed in the gate; `some` =
-- at least one proof obligation was discharged in that run.

record Prover where
  constructor MkProver
  name        : String
  claimed     : Bool
  ran         : Bool
  obligations : Bool   -- True = some, False = none

data Claim = ClaimPass | ClaimFail

record Report where
  constructor MkReport
  provers : List Prover
  claim   : Claim

data Outcome = Silent | Fired

-- =============================================================================
-- THE CHECK
-- =============================================================================

||| Theatre: a claim with nothing behind it — the prover did not run, or ran
||| over nothing.
theatre : Prover -> Bool
theatre p = p.claimed && (not p.ran || not p.obligations)

anyTheatre : List Prover -> Bool
anyTheatre = any theatre

||| The PASS-claim verdict as a total function of "is any claim theatre?" —
||| named so the lemmas below are plain `cong`.
verdictOnPass : Bool -> Outcome
verdictOnPass True  = Fired
verdictOnPass False = Silent

||| Fires exactly when the gate claims PASS over a theatrical claim. A FAIL
||| claim is the honest report of theatre and never fires.
check : Report -> Outcome
check (MkReport provers ClaimPass) = verdictOnPass (anyTheatre provers)
check (MkReport provers ClaimFail) = Silent

-- =============================================================================
-- PROVEN-EXACT WARRANT (error-model.a2ml cites these by name)
-- =============================================================================

||| beta = 0: EVERY report claiming PASS over a theatrical claim fires.
export
firesOnTheatrePass : (provers : List Prover) -> anyTheatre provers = True
                  -> check (MkReport provers ClaimPass) = Fired
firesOnTheatrePass provers prf = cong verdictOnPass prf

||| alpha = 0: a PASS claim with no theatrical claim NEVER fires.
export
silentOnHonestPass : (provers : List Prover) -> anyTheatre provers = False
                  -> check (MkReport provers ClaimPass) = Silent
silentOnHonestPass provers prf = cong verdictOnPass prf

||| The unadvertised-proof confusable, discharged: a prover nobody claims is
||| never theatre, whatever it did or did not do.
export
unclaimedIsNotTheatre : (n : String) -> (ran, obligations : Bool)
                     -> theatre (MkProver n False ran obligations) = False
unclaimedIsNotTheatre n ran obligations = Refl

||| The honest-claim control, discharged: a claimed prover that ran and
||| discharged obligations is proof, not theatre.
export
dischargedClaimIsNotTheatre : (n : String) -> theatre (MkProver n True True True) = False
dischargedClaimIsNotTheatre n = Refl

-- =============================================================================
-- PARSER — strict; anything it cannot read is VOID, never silence
-- =============================================================================

parseYesNo : String -> Maybe Bool
parseYesNo "yes" = Just True
parseYesNo "no"  = Just False
parseYesNo _     = Nothing

parseObligations : String -> Maybe Bool
parseObligations "some" = Just True
parseObligations "none" = Just False
parseObligations _      = Nothing

data Line = LProver Prover | LVerdict Claim

parseLine : String -> Maybe Line
parseLine s = case words s of
  ["prover", n, "claimed", c, "ran", r, "obligations", o] =>
    (\pc, pr, po => LProver (MkProver n pc pr po))
      <$> parseYesNo c <*> parseYesNo r <*> parseObligations o
  ["verdict", "PASS"] => Just (LVerdict ClaimPass)
  ["verdict", "FAIL"] => Just (LVerdict ClaimFail)
  _                   => Nothing

||| At least one prover line, exactly one verdict line, verdict last.
parseReport : String -> Maybe Report
parseReport content = go [] (filter (\l => trim l /= "") (lines content))
  where
    go : List Prover -> List String -> Maybe Report
    go acc [] = Nothing
    go acc (l :: rest) = case parseLine l of
      Just (LProver p)  => go (acc ++ [p]) rest
      Just (LVerdict c) => case (acc, rest) of
                             ([], _)      => Nothing
                             (_,  [])     => Just (MkReport acc c)
                             (_,  _ :: _) => Nothing
      Nothing           => Nothing

-- =============================================================================
-- ENTRY POINT
-- =============================================================================

-- `covering`, not total: readFile consumes fuel until EOF. Every pure function
-- above — the check and its warrant lemmas — remains under %default total.
covering
main : IO ()
main = do
  args <- getArgs
  case args of
    [_, path] => do
      Right content <- readFile path
        | Left err => do putStrLn ("NO CHECK PERFORMED: cannot read " ++ path)
                         exitWith (ExitFailure 2)
      case parseReport content of
        Nothing => do
          putStrLn "NO CHECK PERFORMED: fixture unparseable or incomplete"
          exitWith (ExitFailure 2)
        Just report => case check report of
          Silent => putStrLn
            "SILENT: every verification claim has a prover run with obligations behind it"
          Fired  => do
            putStrLn "FIRED: proof-claim-without-prover — verdict PASS while a claimed prover never ran or ran over no obligations (proof theatre; must be FAIL)"
            exitWith (ExitFailure 1)
    _ => do putStrLn "usage: proof-claim-without-prover <report-file>  (NO CHECK PERFORMED)"
            exitWith (ExitFailure 2)
