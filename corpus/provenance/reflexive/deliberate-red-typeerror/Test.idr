-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

||| Corpus unit: cancelled-gate-void  (battery: provenance, category: reflexive)
|||
||| Ground truth (measured on proven's CI, 2026-08-27): a gate whose
||| adjudicating job is cancelled must not be reported as anything but VOID.
||| proven's `idris2 --build` job hit its 45-minute timeout every run, so the
||| step named "Type check all modules" NEVER executed — and the gate still
||| read as green. This unit is that defect class, made permanently firable.
|||
||| The checker inspects a gate report — each job's conclusion plus the verdict
||| the gate claimed — and FIRES when the report claims PASS while at least one
||| job's conclusion is `cancelled`. A `skipped` conclusion never fires: skips
||| are condition-gated and intentional; a cancellation means the job should
||| have run and did not.
|||
||| Exit convention (docs/TEST-DOCTRINE.adoc — outcomes are 0/1/2):
|||   0 = check ran, report consistent            (SILENT)
|||   1 = check ran, defect present               (FIRED:
|||         cancelled-adjudicator-reported-as-pass)
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
-- One job per line, one verdict line last, nothing else:
--   job <name> conclusion <success|cancelled|skipped>
--   verdict <PASS|FAIL>
-- Anything outside this grammar makes the fixture unparseable: exit 2, because
-- an assertion about a report we could not read has no truth conditions.

data Conclusion = CSuccess | CCancelled | CSkipped

record Job where
  constructor MkJob
  name       : String
  conclusion : Conclusion

data Claim = ClaimPass | ClaimFail

record Report where
  constructor MkReport
  jobs  : List Job
  claim : Claim

data Outcome = Silent | Fired

-- =============================================================================
-- THE CHECK
-- =============================================================================

isCancelled : Job -> Bool
isCancelled j = case j.conclusion of
  CCancelled => True
  _          => False

anyCancelled : List Job -> Bool
anyCancelled = any isCancelled

||| The PASS-claim verdict as a total function of "was anything cancelled?" —
||| named (rather than an inline `if`) so the lemmas below are plain `cong`.
verdictOnPass : Bool -> Outcome
verdictOnPass True  = Fired
verdictOnPass False = Silent

||| Fires exactly when the gate claims PASS over a cancelled job. A FAIL claim
||| over a cancelled job is a conservative misreport (red instead of VOID) and
||| is out of this unit's declared axis — see diagnosticity.a2ml
||| `does_not_distinguish`.
check : Report -> Outcome
check (MkReport jobs ClaimPass) = verdictOnPass (anyCancelled jobs)
check (MkReport jobs ClaimFail) = Silent

-- =============================================================================
-- PROVEN-EXACT WARRANT (error-model.a2ml cites these by name)
-- =============================================================================
-- Total, machine-checked lemmas: within the fixture grammar, alpha = beta = 0
-- by construction. Parse failures are VOID by construction, so the grammar
-- boundary is the declared scope, not a hidden hole.

||| beta = 0: EVERY report claiming PASS over a cancelled job fires.
export
firesOnCancelledPass : (jobs : List Job) -> anyCancelled jobs = True
                    -> check (MkReport jobs ClaimPass) = Fired
firesOnCancelledPass jobs prf = cong verdictOnPass prf

||| alpha = 0: a PASS claim with no cancelled job NEVER fires.
export
silentOnCleanPass : (jobs : List Job) -> anyCancelled jobs = False
                 -> check (MkReport jobs ClaimPass) = Silent
silentOnCleanPass jobs prf = cong verdictOnPass prf

||| The skipped/cancelled confusable, discharged: a skipped job is not a
||| cancelled job, so skips alone can never fire this unit.
export
skippedIsNotCancelled : (n : String) -> isCancelled (MkJob n CSkipped) = False
skippedIsNotCancelled n = Refl

-- =============================================================================
-- PARSER — strict; anything it cannot read is VOID, never silence
-- =============================================================================

parseConclusion : String -> Maybe Conclusion
parseConclusion "success"   = Just CSuccess
parseConclusion "cancelled" = Just CCancelled
parseConclusion "skipped"   = Just CSkipped
parseConclusion _           = Nothing

data Line = LJob Job | LVerdict Claim

parseLine : String -> Maybe Line
parseLine s = case words s of
  ["job", n, "conclusion", c] => (\pc => LJob (MkJob n pc)) <$> parseConclusion c
  ["verdict", "PASS"]         => Just (LVerdict ClaimPass)
  ["verdict", "FAIL"]         => Just (LVerdict ClaimFail)
  _                           => Nothing

||| At least one job line, exactly one verdict line, verdict last.
parseReport : String -> Maybe Report
parseReport content = go [] (filter (\l => trim l /= "") (lines content))
  where
    go : List Job -> List String -> Maybe Report
    go acc [] = Nothing
    go acc (l :: rest) = case parseLine l of
      Just (LJob j)     => go (acc ++ [j]) rest
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
            "SILENT: no cancelled job behind a PASS claim"
          Fired  => do
            putStrLn "FIRED: cancelled-adjudicator-reported-as-pass — verdict PASS while a job's conclusion is cancelled (must be VOID)"
            exitWith (ExitFailure 1)
    _ => do putStrLn "usage: cancelled-gate-void <report-file>  (NO CHECK PERFORMED)"
            exitWith (ExitFailure 2)

-- ⚠ DELIBERATE TYPE ERROR (R-40). Proves corpus-check reds because of the
-- corpus, not because of its harness. Removed in the following commit.
deliberateRedCanary : Nat
deliberateRedCanary = "this is not a Nat"
