-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.Main

import ProvenTests.Types
import ProvenTests.Baton
import ProvenSubject.Ledger
import ProvenSubject.Grading
import ProvenSubject.GoldenVectors
import System
import System.File
import Data.String
import Data.List

%default covering

-- =============================================================================
-- proven-subject-report — grade proven's modules by three-tier provenance
-- =============================================================================
-- Reads proven's own ledgers (no code dependency on proven) and grades every
-- module, then prints the as-declared vs strict readings and the drift between
-- them. The subject root comes from PROVEN_ROOT or argv[1] (default /home/user/proven).

trustDisclaimer : String
trustDisclaimer = unlines
  [ "-- TRUST NOTE ----------------------------------------------------------------"
  , "This report is derived entirely from proven's OWN self-audit artifacts"
  , "(MODULE-STATUS.txt + .machine_readable/descriptiles/STATE.a2ml). The proofs are NOT"
  , "re-checked here; the grading only reflects what proven already states about"
  , "itself. 'Actually-Proven' under the strict reading additionally requires a"
  , "module to sit in proven's own zero-OWED clean set."
  , "----------------------------------------------------------------------------" ]

resolveRoot : List String -> IO String
resolveRoot args = do
  fromEnv <- getEnv "PROVEN_ROOT"
  pure $ case (fromEnv, args) of
    (Just r, _)          => r
    (Nothing, (_ :: r :: _)) => r
    _                    => "/home/user/proven"

readOr : String -> IO (Maybe String)
readOr path = do
  Right contents <- readFile path
    | Left _ => pure Nothing
  pure (Just contents)

readOwed : String -> IO (String, String)
readOwed root = do
  canonical <- readOr (root ++ "/.machine_readable/descriptiles/STATE.a2ml")
  case canonical of
    Just contents => pure (".machine_readable/descriptiles/STATE.a2ml", contents)
    Nothing => do
      -- Compatibility for subjects not yet migrated to the canonical
      -- descriptile location. This path already exists in the current proven
      -- checkout and must remain readable until that repository migrates.
      Just contents <- readOr (root ++ "/.machine_readable/6a2/STATE.a2ml")
        | Nothing => do
            putStrLn "ERROR: cannot read proven's STATE.a2ml from the canonical or legacy location"
            exitFailure
      pure (".machine_readable/6a2/STATE.a2ml (legacy)", contents)

showGraded : Graded -> String
showGraded g =
  padRight 20 ' ' (modName g)
    ++ padRight 9 ' ' (show (statusOfGraded g))
    ++ " " ++ rationale g

partition3 : List Graded -> (List Graded, List Graded, List Graded)
partition3 gs =
  ( filter (\g => statusOfGraded g == ActuallyProven) gs
  , filter (\g => statusOfGraded g == ProvisionallyProven) gs
  , filter (\g => statusOfGraded g == Unproven) gs )

runReport : List String -> IO ()
runReport args = do
  root <- resolveRoot args
  putStrLn "=== proven-subject-report: three-tier provenance grading of proven ==="
  putStrLn ("subject root: " ++ root)
  putStrLn ""
  putStr trustDisclaimer
  putStrLn ""

  Just statusTxt <- readOr (root ++ "/MODULE-STATUS.txt")
    | Nothing => do putStrLn ("ERROR: cannot read " ++ root ++ "/MODULE-STATUS.txt")
                    exitFailure
  (owedPath, owedTxt) <- readOwed root
  let led = parseOwedLedger owedTxt

  let mods = parseModuleStatus statusTxt
  let declared = map gradeDeclared mods
  let strict   = map (gradeStrict led) mods
  let dc = countTiers declared
  let sc = countTiers strict

  putStrLn ("modules parsed: " ++ show (length mods))
  putStrLn ("OWED ledger (" ++ owedPath ++ "): "
              ++ show (bodylessTotal led) ++ " outstanding axioms, "
              ++ show (discharged led) ++ " discharged, "
              ++ show (cleanModules led) ++ " clean modules")
  putStrLn ""

  putStrLn "== As-declared reading (trust MODULE-STATUS tier verbatim) =="
  putStrLn ("  " ++ show dc)
  putStrLn ""
  putStrLn "== Strict reading (evidence-carrying: Actually needs proofs AND zero OWED) =="
  putStrLn ("  " ++ show sc)
  putStrLn ""

  let drift = minus (actually dc) (actually sc)
  putStrLn ("== DRIFT: " ++ show drift ++ " module(s) proven DECLARES as first-class/proven"
             ++ " but do NOT meet strict evidence-carrying Actually-Proven ==")
  putStrLn ""

  let (sa, sp, su) = partition3 strict
  putStrLn "-- Strict Actually-Proven --"
  if null sa then putStrLn "  (none — no module is both proof-bearing and in the zero-OWED clean set)"
             else traverse_ (putStrLn . ("  " ++) . showGraded) sa
  putStrLn ""
  putStrLn ("-- Strict Provisionally-Proven (" ++ show (length sp) ++ ") --")
  traverse_ (putStrLn . ("  " ++) . showGraded) (take 8 sp)
  when (length sp > 8) $ putStrLn ("  ... and " ++ show (minus (length sp) 8) ++ " more")
  putStrLn ""
  putStrLn ("-- Strict Unproven (" ++ show (length su) ++ ") --")
  traverse_ (putStrLn . ("  " ++) . showGraded) (take 6 su)
  when (length su > 6) $ putStrLn ("  ... and " ++ show (minus (length su) 6) ++ " more")
  putStrLn ""

  -- Sanity gate mirroring the plan: strict Actually-Proven must be <= declared
  -- FIRST-CLASS count, and the whole report reconciles the module count.
  let ok = actually sc <= actually dc && length mods > 0
  if ok
    then putStrLn "proven-subject-report: OK"
    else do putStrLn "proven-subject-report: FAILED sanity gate"
            exitFailure

main : IO ()
main = do
  args <- getArgs
  -- `golden` subcommand: emit the FFI-parity golden vectors as JSONL and exit.
  if "golden" `elem` args
    then putStr goldenJsonl
    else runReport args
