-- SPDX-License-Identifier: MPL-2.0
-- Corpus unit: merge-bypass-required-gates, 2026-11-15
-- A merge over an unsatisfied required rule is not a completed assurance
-- result. The outcome is narrow: it identifies a *bypass event*, not who
-- initiated the bypass or whether an external emergency process authorised it.
module Test

import Data.String
import System
import System.File

%default total

data RuleStatus = RulePass | RuleFail

record Rule where
  constructor MkRule
  name      : String
  required  : Bool
  ruleState : RuleStatus

data Ruleset = RulesPass | RulesBypass | RulesFail

data Merge = Merged | Blocked

record Report where
  constructor MkReport
  ruleset  : Ruleset
  rules    : List Rule
  decision : Merge

data Outcome = Silent | Fired

||| Only a rule independently declared REQUIRED is relevant to this check.
failedRequired : Rule -> Bool
failedRequired (MkRule _ True RuleFail) = True
failedRequired _                        = False

anyFailedRequired : List Rule -> Bool
anyFailedRequired = any failedRequired

onBypassedMerge : Bool -> Outcome
onBypassedMerge True  = Fired
onBypassedMerge False = Silent

||| A complete merge attributed to a bypass is an incident if at least one
||| required rule failed. A merely attempted, blocked merge is not such an
||| incident, nor is an optional advisory failure.
check : Report -> Outcome
check (MkReport RulesBypass rules Merged) =
  onBypassedMerge (anyFailedRequired rules)
check _ = Silent

||| beta=0 within the strict report grammar: all bypassed merges over any
||| failed required rule fire, irrespective of rule position or list length.
export
firesOnBypassedRequired : (rules : List Rule) ->
  anyFailedRequired rules = True ->
  check (MkReport RulesBypass rules Merged) = Fired
firesOnBypassedRequired rules prf = cong onBypassedMerge prf

||| alpha=0: when no required rule failed, the same bypass report does not
||| fire (the checker does not infer a violation from the bypass label alone).
export
silentOnNoFailedRequired : (rules : List Rule) ->
  anyFailedRequired rules = False ->
  check (MkReport RulesBypass rules Merged) = Silent
silentOnNoFailedRequired rules prf = cong onBypassedMerge prf

export
optionalFailureIsNotRequired : (label : String) ->
  failedRequired (MkRule label False RuleFail) = False
optionalFailureIsNotRequired label = Refl

export
blockedBypassIsNotMerged : (rules : List Rule) ->
  check (MkReport RulesBypass rules Blocked) = Silent
blockedBypassIsNotMerged rules = Refl

parseRuleset : String -> Maybe Ruleset
parseRuleset s = case words s of
  ["ruleset", "pass"]   => Just RulesPass
  ["ruleset", "bypass"] => Just RulesBypass
  ["ruleset", "fail"]   => Just RulesFail
  _                      => Nothing

parseRequired : String -> Maybe Bool
parseRequired "yes" = Just True
parseRequired "no"  = Just False
parseRequired _     = Nothing

parseRuleStatus : String -> Maybe RuleStatus
parseRuleStatus "pass" = Just RulePass
parseRuleStatus "fail" = Just RuleFail
parseRuleStatus _      = Nothing

parseRule : String -> Maybe Rule
parseRule s = case words s of
  ["rule", n, "required", e, "result", c] =>
    case (parseRequired e, parseRuleStatus c) of
      (Just r, Just st) => Just (MkRule n r st)
      _                 => Nothing
  _ => Nothing

||| The grammar permits exactly one ruleset line first, one or more rule
||| lines, and exactly one terminal decision. Invalid or empty is VOID.
parseBody : Ruleset -> List Rule -> List String -> Maybe Report
parseBody r acc [] = Nothing
parseBody r [] [last] = Nothing
parseBody r acc [last] = case words last of
  ["decision", "merged"]  => Just (MkReport r acc Merged)
  ["decision", "blocked"] => Just (MkReport r acc Blocked)
  _ => Nothing
parseBody r acc (line :: rest) =
  case parseRule line of
    Just rule => parseBody r (acc ++ [rule]) rest
    Nothing   => Nothing

parseReport : String -> Maybe Report
parseReport content =
  case filter (\s => trim s /= "") (lines content) of
    [] => Nothing
    header :: body => case parseRuleset header of
      Just r => parseBody r [] body
      Nothing => Nothing

covering
main : IO ()
main = do
  args <- getArgs
  case args of
    [_, path] => do
      contents <- readFile path
      case contents of
        Left err => do
          putStrLn ("NO CHECK PERFORMED: unreadable report: " ++ path)
          exitWith (ExitFailure 2)
        Right txt =>
          case parseReport txt of
            Nothing => do
              putStrLn "NO CHECK PERFORMED: missing or invalid report"
              exitWith (ExitFailure 2)
            Just report =>
              case check report of
                Fired => do
                  putStrLn "FIRED: merge-bypass-required-gates"
                  exitWith (ExitFailure 1)
                Silent => do
                  putStrLn "SILENT: no bypassed merge over a failed required rule"
                  exitSuccess
    _ => do
      putStrLn "NO CHECK PERFORMED: expected exactly one report filename"
      exitWith (ExitFailure 2)