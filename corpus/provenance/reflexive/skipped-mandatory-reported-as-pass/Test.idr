-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

||| Corpus unit: skipped-mandatory-reported-as-pass
||| (battery: provenance, category: reflexive)
|||
||| Ground truth (platform behaviour, the reason every cicd-suite language
||| gate carries a verdict job): a GitHub Actions job skipped by its `if:`
||| reports conclusion `skipped`, and a required status check whose conclusion
||| is `skipped` does not block a merge. So a gate whose mandatory job —
||| `check`, `prove`, `test` — is skipped by a mis-evaluated condition, or by
||| an upstream job that never produced the output it gates on, reads green
||| with nothing checked. This is the skipped twin of `cancelled-gate-void`:
||| there, the job was meant to run and was killed; here, the job was meant to
||| run and was never started, and the platform calls that a pass.
|||
||| The checker inspects a gate report — for each job, whether the gate
||| declared it mandatory, plus its conclusion, plus the verdict the gate
||| claimed — and FIRES when the report claims PASS while a mandatory job's
||| conclusion is `skipped`. An optional job (one the gate declared it does
||| not expect on this tree — a coverage job on a tree with no coverage floor)
||| may be skipped freely: that is the intended, condition-gated skip.
|||
||| Exit convention (docs/TEST-DOCTRINE.adoc — outcomes are 0/1/2):
|||   0 = check ran, report consistent            (SILENT)
|||   1 = check ran, defect present               (FIRED:
|||         skipped-mandatory-reported-as-pass)
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
--   job <name> expected <yes|no> conclusion <success|skipped|failure>
--   verdict <PASS|FAIL|VOID>
-- `expected yes` = the gate itself declared this job mandatory for the tree
-- under test (cicd-suite's detect job writes exactly this fact); `expected no`
-- = the job is condition-gated and may legitimately not run.

data Expected = Mandatory | Optional

data Conclusion = CSuccess | CSkipped | CFailure

record Job where
  constructor MkJob
  name       : String
  expected   : Expected
  conclusion : Conclusion

data Claim = ClaimPass | ClaimFail | ClaimVoid

record Report where
  constructor MkReport
  jobs  : List Job
  claim : Claim

data Outcome = Silent | Fired

-- =============================================================================
-- THE CHECK
-- =============================================================================

||| A job the gate declared mandatory that never ran.
skippedMandatory : Job -> Bool
skippedMandatory (MkJob _ Mandatory CSkipped) = True
skippedMandatory _                            = False

anySkippedMandatory : List Job -> Bool
anySkippedMandatory = any skippedMandatory

||| The PASS-claim verdict as a total function of "was a mandatory job
||| skipped?" — named so the lemmas below are plain `cong`.
verdictOnPass : Bool -> Outcome
verdictOnPass True  = Fired
verdictOnPass False = Silent

||| Fires exactly when the gate claims PASS over a skipped mandatory job. A
||| FAIL or VOID claim over the same jobs is a conservative or honest report
||| and never fires here.
check : Report -> Outcome
check (MkReport jobs ClaimPass) = verdictOnPass (anySkippedMandatory jobs)
check (MkReport jobs ClaimFail) = Silent
check (MkReport jobs ClaimVoid) = Silent

-- =============================================================================
-- PROVEN-EXACT WARRANT (error-model.a2ml cites these by name)
-- =============================================================================

||| beta = 0: EVERY report claiming PASS over a skipped mandatory job fires.
export
firesOnSkippedMandatoryPass : (jobs : List Job) -> anySkippedMandatory jobs = True
                           -> check (MkReport jobs ClaimPass) = Fired
firesOnSkippedMandatoryPass jobs prf = cong verdictOnPass prf

||| alpha = 0: a PASS claim with no skipped mandatory job NEVER fires.
export
silentOnCleanPass : (jobs : List Job) -> anySkippedMandatory jobs = False
                 -> check (MkReport jobs ClaimPass) = Silent
silentOnCleanPass jobs prf = cong verdictOnPass prf

||| The optional-skip confusable, discharged: a job the gate did not expect
||| may be skipped without ever satisfying the firing predicate.
export
optionalSkipIsNotMandatory : (n : String) -> skippedMandatory (MkJob n Optional CSkipped) = False
optionalSkipIsNotMandatory n = Refl

||| The failed-mandatory confusable, discharged: a mandatory job that RAN and
||| failed is a real failure, not a skip, and is outside this unit's axis.
export
failedMandatoryIsNotSkipped : (n : String) -> skippedMandatory (MkJob n Mandatory CFailure) = False
failedMandatoryIsNotSkipped n = Refl

-- =============================================================================
-- PARSER — strict; anything it cannot read is VOID, never silence
-- =============================================================================

parseExpected : String -> Maybe Expected
parseExpected "yes" = Just Mandatory
parseExpected "no"  = Just Optional
parseExpected _     = Nothing

parseConclusion : String -> Maybe Conclusion
parseConclusion "success" = Just CSuccess
parseConclusion "skipped" = Just CSkipped
parseConclusion "failure" = Just CFailure
parseConclusion _         = Nothing

data Line = LJob Job | LVerdict Claim

parseLine : String -> Maybe Line
parseLine s = case words s of
  ["job", n, "expected", e, "conclusion", c] =>
    (\pe, pc => LJob (MkJob n pe pc)) <$> parseExpected e <*> parseConclusion c
  ["verdict", "PASS"] => Just (LVerdict ClaimPass)
  ["verdict", "FAIL"] => Just (LVerdict ClaimFail)
  ["verdict", "VOID"] => Just (LVerdict ClaimVoid)
  _                   => Nothing

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
            "SILENT: no skipped mandatory job behind a PASS claim"
          Fired  => do
            putStrLn "FIRED: skipped-mandatory-reported-as-pass — verdict PASS while a job the gate declared mandatory was skipped (must be VOID)"
            exitWith (ExitFailure 1)
    _ => do putStrLn "usage: skipped-mandatory-reported-as-pass <report-file>  (NO CHECK PERFORMED)"
            exitWith (ExitFailure 2)
