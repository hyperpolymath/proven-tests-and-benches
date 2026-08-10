-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module Benchmark

import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Dyadic
import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.Coverage
import ProvenTests.Taxonomy
import ProvenTests.Zigzag
import System
import System.Clock
import System.File
import Data.List
import Data.Maybe
import Data.Nat

-- =============================================================================
-- HONEST BENCHMARK HARNESS
-- =============================================================================
-- Real wall-clock timing via the monotonic clock. Workloads are indexed by the
-- iteration counter so results are NOT memoised, and every result is folded
-- into a checksum that is printed, so the optimiser cannot eliminate the work
-- as dead code.
--
-- MEASUREMENT DISCIPLINE (2026-08-10, ultraplan Phase 3a)
-- -------------------------------------------------------
-- * Each workload runs REPS times; every sample is recorded and the MEDIAN is
--   the headline number. Hosted runners are noisy; a single sample is not a
--   measurement.
-- * Per-workload iteration counts are calibrated so one sample costs tens of
--   milliseconds — a 20 µs total is timer-resolution noise, not data.
-- * `--json <path>` writes the machine-readable result set (schema below);
--   stdout keeps the human lines. The JSON is what baselines are computed
--   from — numbers ship with artifacts, never merely asserted.
-- * WORKLOADS ARE FROZEN as of this commit: baselines are per-workload, and
--   any change to a workload's definition invalidates its history. Changing
--   one requires cutting a new baseline (taxonomy: baselines are versioned).
--
-- Composition note (Six Sigma classifier, Phase 3b): when benchmark costs are
-- composed, sequential composition ADDS (⊗ = +) and parallel composition takes
-- the BOTTLENECK (⊕ = max) — the max-plus grading identified in the estate's
-- tropical-types work. The classifier consumes per-workload numbers; it never
-- sums parallel branches.

public export
record BenchmarkResult where
  constructor MkBenchmarkResult
  name       : String
  iterations : Nat
  samples_ns : List Integer  -- one total per repetition, in run order
  median_ns  : Integer       -- headline: median of samples
  checksum   : Bool

--/ Median of a list of Integers (0 for empty — callers never pass empty).
--/ For even lengths this takes the upper middle: with REPS = 5 the length is
--/ odd and this is the exact median.
median : List Integer -> Integer
median xs =
  let sorted = sort xs
      mid = divNatNZ (length sorted) 2 SIsNonZero
  in case drop mid sorted of
       (m :: _) => m
       []       => 0

export
Show BenchmarkResult where
  show r =
    name r ++ ": " ++ show (iterations r) ++ " iters, "
    ++ show (median_ns r) ++ " ns median of " ++ show (length (samples_ns r))
    ++ " samples " ++ show (samples_ns r)
    ++ " [checksum=" ++ show (checksum r) ++ "]"

-- Total nanoseconds held by a clock value
toNanos : Clock type -> Integer
toNanos c = seconds c * 1000000000 + nanoseconds c

-- Time an IO action, returning its result and the elapsed nanoseconds
timeIO : IO a -> IO (a, Integer)
timeIO act = do
  start <- clockTime Monotonic
  res   <- act
  end   <- clockTime Monotonic
  pure (res, toNanos end - toNanos start)

-- Strict loop: applies the index-varied workload n times, threading the result
-- through a running XOR checksum so nothing can be elided.
benchLoop : Nat -> (Nat -> Bool) -> Bool -> Bool
benchLoop Z     _ acc = acc
benchLoop (S k) f acc = benchLoop k f (acc /= f (S k))

-- One timed sample of `n` iterations. The `if` forces the loop's result to be
-- evaluated between the two clock reads.
sample : Nat -> (Nat -> Bool) -> IO (Bool, Integer)
sample n f = timeIO (if benchLoop n f False then pure True else pure False)

--/ Repetitions per workload per run.
public export
REPS : Nat
REPS = 5

-- Run a named workload REPS times and record every sample.
benchmark : String -> Nat -> (Nat -> Bool) -> IO BenchmarkResult
benchmark nm n f = do
  results <- traverse (\_ => sample n f) [1 .. REPS]
  let times = map snd results
  let chk = foldl (\a, (b, _) => a /= b) False results
  pure (MkBenchmarkResult nm n times (median times) chk)

-- =============================================================================
-- WORKLOADS (real, input-dependent functions from the framework) — FROZEN
-- =============================================================================

-- Validate an effect stack of length proportional to i
wlEffects : Nat -> Bool
wlEffects i = effectStackValid (replicate i Read)

-- Transitivity of equality at (i, i, i): the antecedent HOLDS, so the
-- consequent is genuinely evaluated.
--
-- NOTE (2026-08-10): this workload used to call (i, i+1, i+2), where the
-- antecedent is false and the implication short-circuits — it was timing the
-- vacuous path at ~10 ns/iter, which is timer noise, and it was the same
-- vacuous-antecedent shape PR #27 removed from the test suite. Fixed BEFORE
-- any baseline was cut, because a baseline freezes its workload.
wlDyadic : Nat -> Bool
wlDyadic i = relationTransitive equalityRelation i i i

-- Walk a ceremony of length proportional to i to find its terminal step
wlCeremony : Nat -> Bool
wlCeremony i =
  ceremonyEndsProperly (MkCeremony (replicate i (Validate "x") ++ [Complete "done"]))

-- Fold coverage derivation over a generated coordinate list (salvaged from the
-- expand-coverage branch, 2026-08-10)
wlCoverage : Nat -> Bool
wlCoverage i =
  let cells = replicate i (MkCoord CoImplementation Collective EndToEnd Dependability)
  in coveredCatAspect cells <= 238

-- Per-workload iteration counts, calibrated 2026-08-10 on the reference dev
-- box so a single sample costs tens of milliseconds (see the discipline note).
-- These numbers are part of the frozen workload definition.
public export
WORKLOADS : List (String, Nat, Nat -> Bool)
WORKLOADS =
  [ ("effectStackValid",     10000, wlEffects)
  , ("relationTransitive", 3000000, wlDyadic)
  , ("ceremonyEndsProperly",  8000, wlCeremony)
  , ("coveredCatAspect",       120, wlCoverage)
  ]

-- =============================================================================
-- JSON EMISSION (manual writer, same style as ProvenTests.Report)
-- =============================================================================

jstr : String -> String
jstr s = "\"" ++ concatMap esc (unpack s) ++ "\""
  where
    esc : Char -> String
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc c    = cast c

jint : Integer -> String
jint = show

jlist : List String -> String
jlist xs = "[" ++ concat (intersperse ", " xs) ++ "]"

resultJSON : BenchmarkResult -> String
resultJSON r = concat
  [ "{ \"name\": ", jstr (name r)
  , ", \"iterations\": ", show (iterations r)
  , ", \"samples_ns\": ", jlist (map jint (samples_ns r))
  , ", \"median_ns\": ", jint (median_ns r)
  , ", \"checksum\": ", if checksum r then "true" else "false"
  , " }"
  ]

--/ The run-level JSON: schema_version, environment identity (commit + runner
--/ metadata from the environment, "unknown" outside CI), and the results.
runJSON : String -> String -> List BenchmarkResult -> String
runJSON commit runner rs = concat
  [ "{ \"schema_version\": 1"
  , ", \"suite\": \"proven-bench\""
  , ", \"reps\": ", show (the Nat REPS)
  , ", \"commit\": ", jstr commit
  , ", \"runner\": ", jstr runner
  , ", \"results\": ", jlist (map resultJSON rs)
  , " }"
  ]

--/ Extract a `--json <path>` argument, if present.
jsonPath : List String -> Maybe String
jsonPath ("--json" :: p :: _) = Just p
jsonPath (_ :: rest)          = jsonPath rest
jsonPath []                   = Nothing

envOr : String -> String -> IO String
envOr key dflt = do
  v <- getEnv key
  pure (fromMaybe dflt v)

-- =============================================================================
-- BENCHMARK ENTRY POINT
-- =============================================================================

public export
benchMain : IO ()
benchMain = do
  args <- getArgs
  putStrLn "=== Proven-Tests Benchmark Suite ==="
  putStrLn "(monotonic clock; median of samples; compare against baseline.json)"
  putStrLn ""
  rs <- traverse (\(nm, n, f) => benchmark nm n f) WORKLOADS
  traverse_ (putStrLn . show) rs
  case jsonPath args of
    Nothing => pure ()
    Just path => do
      commit <- envOr "GITHUB_SHA" "unknown"
      runner <- envOr "RUNNER_OS" "local"
      Right () <- writeFile path (runJSON commit runner rs)
        | Left err => do
            putStrLn ("bench: could not write " ++ path ++ ": " ++ show err)
            exitFailure
      putStrLn ("bench: wrote " ++ path)

main : IO ()
main = benchMain
