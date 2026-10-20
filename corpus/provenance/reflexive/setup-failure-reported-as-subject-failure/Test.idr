-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

||| Corpus unit: setup-failure-reported-as-subject-failure
||| (battery: provenance, category: reflexive)
|||
||| Ground truth (measured on plasma-parser-writer's CI, 2026-09-29 to
||| 2026-10-14, e.g. run 38564229091): `rust-ci / Cargo check + clippy + fmt`
||| was red on every run and every red read as a code failure. The job died in
||| its toolchain-install step — `'toolchain' is a required input`, raised by a
||| SHA-pinned dtolnay/rust-toolchain that was passed no `toolchain:` — before
||| a compiler existed. No cargo command ran. The verdict the gate carried was
||| FAIL, as if the subject had been checked and found wanting. The only
||| honest verdict over a check that never began is VOID.
|||
||| The checker inspects a gate report — for each job, where it failed (in a
||| setup step, in the subject step, or nowhere) plus the verdict the gate
||| claimed — and FIRES when the report claims FAIL while every failure it
||| records is a setup failure. A report with at least one subject failure is
||| a real FAIL and never fires, whatever else died. A VOID claim never fires:
||| it is the honest form.
|||
||| Exit convention (docs/TEST-DOCTRINE.adoc — outcomes are 0/1/2):
|||   0 = check ran, report consistent            (SILENT)
|||   1 = check ran, defect present               (FIRED:
|||         setup-failure-reported-as-subject-failure)
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
--   job <name> failed-at <setup|subject|none>
--   verdict <PASS|FAIL|VOID>
-- `setup` = the job failed before its subject step ran (checkout, toolchain
-- install, an action's input validation); `subject` = the subject check ran
-- and failed; `none` = the job succeeded. Anything outside this grammar makes
-- the fixture unparseable: exit 2.

data FailedAt = AtSetup | AtSubject | Nowhere

record Job where
  constructor MkJob
  name     : String
  failedAt : FailedAt

data Claim = ClaimPass | ClaimFail | ClaimVoid

record Report where
  constructor MkReport
  jobs  : List Job
  claim : Claim

data Outcome = Silent | Fired

-- =============================================================================
-- THE CHECK
-- =============================================================================

failedAtSetup : Job -> Bool
failedAtSetup j = case j.failedAt of
  AtSetup => True
  _       => False

failedAtSubject : Job -> Bool
failedAtSubject j = case j.failedAt of
  AtSubject => True
  _         => False

anySetup : List Job -> Bool
anySetup = any failedAtSetup

anySubject : List Job -> Bool
anySubject = any failedAtSubject

||| The FAIL-claim verdict as a total function of (any subject failure?, any
||| setup failure?). The subject question is asked FIRST: a real subject
||| failure makes the FAIL claim honest whatever else died.
verdictOnFail : (subject : Bool) -> (setup : Bool) -> Outcome
verdictOnFail True  _     = Silent
verdictOnFail False True  = Fired
verdictOnFail False False = Silent

||| Fires exactly when the gate claims FAIL and every recorded failure is a
||| setup failure. PASS and VOID claims are outside the firing predicate: a
||| PASS over a setup failure is a different defect (a check that never ran
||| reported green — see the sibling units), and VOID is the honest form.
check : Report -> Outcome
check (MkReport jobs ClaimFail) = verdictOnFail (anySubject jobs) (anySetup jobs)
check (MkReport jobs ClaimPass) = Silent
check (MkReport jobs ClaimVoid) = Silent

-- =============================================================================
-- PROVEN-EXACT WARRANT (error-model.a2ml cites these by name)
-- =============================================================================

||| beta = 0: EVERY report claiming FAIL whose failures are all setup
||| failures fires.
export
firesOnSetupOnlyFail : (jobs : List Job) -> anySubject jobs = False
                    -> anySetup jobs = True
                    -> check (MkReport jobs ClaimFail) = Fired
firesOnSetupOnlyFail jobs noSubject someSetup = cong2 verdictOnFail noSubject someSetup

||| alpha = 0 (i): a FAIL claim with a subject failure NEVER fires, whatever
||| else failed around it.
export
silentOnSubjectFail : (jobs : List Job) -> anySubject jobs = True
                   -> check (MkReport jobs ClaimFail) = Silent
silentOnSubjectFail jobs someSubject =
  cong (\s => verdictOnFail s (anySetup jobs)) someSubject

||| alpha = 0 (ii): a FAIL claim over no failure at all never fires here. A
||| FAIL over nothing is a different defect, outside this unit's declared axis
||| (diagnosticity.a2ml `does_not_distinguish`).
export
silentOnNoFailure : (jobs : List Job) -> anySubject jobs = False
                 -> anySetup jobs = False
                 -> check (MkReport jobs ClaimFail) = Silent
silentOnNoFailure jobs noSubject noSetup = cong2 verdictOnFail noSubject noSetup

||| The confusable, discharged: a VOID claim over a setup failure is the
||| HONEST report and can never fire, for every job list.
export
voidClaimNeverFires : (jobs : List Job) -> check (MkReport jobs ClaimVoid) = Silent
voidClaimNeverFires jobs = Refl

-- =============================================================================
-- PARSER — strict; anything it cannot read is VOID, never silence
-- =============================================================================

parseFailedAt : String -> Maybe FailedAt
parseFailedAt "setup"   = Just AtSetup
parseFailedAt "subject" = Just AtSubject
parseFailedAt "none"    = Just Nowhere
parseFailedAt _         = Nothing

data Line = LJob Job | LVerdict Claim

parseLine : String -> Maybe Line
parseLine s = case words s of
  ["job", n, "failed-at", w] => (\f => LJob (MkJob n f)) <$> parseFailedAt w
  ["verdict", "PASS"]        => Just (LVerdict ClaimPass)
  ["verdict", "FAIL"]        => Just (LVerdict ClaimFail)
  ["verdict", "VOID"]        => Just (LVerdict ClaimVoid)
  _                          => Nothing

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
            "SILENT: no FAIL claim rests on setup failures alone"
          Fired  => do
            putStrLn "FIRED: setup-failure-reported-as-subject-failure — verdict FAIL while every failure is a setup failure; the subject was never checked (must be VOID)"
            exitWith (ExitFailure 1)
    _ => do putStrLn "usage: setup-failure-reported-as-subject-failure <report-file>  (NO CHECK PERFORMED)"
            exitWith (ExitFailure 2)
