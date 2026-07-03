-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.Ledger

import Data.String
import Data.List
import Data.List1
import Data.Maybe

%default total

-- =============================================================================
-- PARSING proven's honest ledgers
-- =============================================================================
-- We read proven's own self-audit artifacts and nothing else — the grading
-- (ProvenSubject.Grading) is derived purely from what proven states about
-- itself, so this report cannot claim more than proven already admits.
--
--   * MODULE-STATUS.txt   — per-module tier (FIRST/SECOND/WIP) + counts
--   * .machine_readable/6a2/STATE.a2ml — the OWED-axiom ledger (aggregate)

public export
data Tier = FirstClass | SecondClass | Wip

public export
Show Tier where
  show FirstClass  = "FIRST-CLASS"
  show SecondClass = "SECOND-CLASS"
  show Wip         = "WIP"

public export
Eq Tier where
  FirstClass  == FirstClass  = True
  SecondClass == SecondClass = True
  Wip         == Wip         = True
  _           == _           = False

--/ One module's line in MODULE-STATUS.txt.
public export
record ModuleStatus where
  constructor MkModuleStatus
  name      : String
  tier      : Tier
  loc       : Maybe Nat   -- Nothing when the file records "???L"
  exports   : Maybe Nat
  proofs    : Maybe Nat   -- only FIRST-CLASS lines carry a proof count

--/ Aggregate proof-obligation figures from STATE.a2ml.
public export
record OwedLedger where
  constructor MkOwedLedger
  bodylessTotal   : Nat   -- outstanding OWED axioms across all Proofs.idr
  discharged      : Nat   -- OWED -> genuinely proven
  cleanModules    : Nat   -- modules with zero bodyless decls
  cleanNames      : List String  -- the named clean set (from the STATE comment)

-- ── small parser helpers ─────────────────────────────────────────────────────

words' : String -> List String
words' = filter (/= "") . forget . split (== ' ')

-- parse a "217L" / "28exp" / "3prf" token stripped of its suffix; "???" -> Nothing
numWithSuffix : String -> String -> Maybe Nat
numWithSuffix suffix tok =
  if isSuffixOf suffix tok
    then let core = substr 0 (minus (length tok) (length suffix)) tok in
         parsePositive core
    else Nothing

firstJust : (a -> Maybe b) -> List a -> Maybe b
firstJust f []        = Nothing
firstJust f (x :: xs) = case f x of
  Just y  => Just y
  Nothing => firstJust f xs

--/ Parse one MODULE-STATUS.txt body line. Returns Nothing for comments/blanks
--/ and section headers.
export
parseStatusLine : String -> Maybe ModuleStatus
parseStatusLine line =
  case words' line of
    (tag :: name :: rest) =>
      do tier <- tierOf tag
         pure (MkModuleStatus name tier
                 (firstJust (numWithSuffix "L") rest)
                 (firstJust (numWithSuffix "exp") rest)
                 (firstJust (numWithSuffix "prf") rest))
    _ => Nothing
  where
    tierOf : String -> Maybe Tier
    tierOf "FIRST"  = Just FirstClass
    tierOf "SECOND" = Just SecondClass
    tierOf "WIP"    = Just Wip
    tierOf _        = Nothing

--/ Parse every module line out of MODULE-STATUS.txt contents.
export
parseModuleStatus : String -> List ModuleStatus
parseModuleStatus = mapMaybe parseStatusLine . lines

-- ── STATE.a2ml OWED ledger ───────────────────────────────────────────────────

-- find `key = <nat>` on any line, tolerant of surrounding whitespace
findNatAssign : String -> String -> Maybe Nat
findNatAssign key content =
  firstJust lineVal (lines content)
  where
    lineVal : String -> Maybe Nat
    lineVal l =
      let ws = words' l in
      case ws of
        (k :: "=" :: v :: _) => if k == key then parsePositive v else Nothing
        _                    => Nothing

--/ Parse the aggregate OWED figures. Missing keys default to 0 / empty so a
--/ format drift degrades gracefully rather than crashing the report.
export
parseOwedLedger : String -> OwedLedger
parseOwedLedger content =
  MkOwedLedger
    (fromMaybe 0 (findNatAssign "bodyless-decls-total" content))
    (fromMaybe 0 (findNatAssign "discharged-decls" content))
    (fromMaybe 0 (findNatAssign "safe-modules-clean" content))
    -- The convention-setting clean set is named in the STATE.a2ml comment;
    -- we hardcode it here since it is not a machine field. If STATE grows a
    -- machine-readable clean list, switch to parsing it.
    ["SafeChecksum", "SafeBuffer", "SafeBloom", "SafeCryptoAccel", "SafeHKDF", "SafeFPGA"]

--/ Is this module in proven's zero-OWED clean set?
export
isClean : OwedLedger -> String -> Bool
isClean led name = name `elem` cleanNames led
