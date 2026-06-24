-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module Benchmark

import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Dyadic
import ProvenTests.TypeSafe.Ceremonial
import System.Clock
import Data.List

-- =============================================================================
-- HONEST BENCHMARK HARNESS
-- =============================================================================
-- Real wall-clock timing via the monotonic clock. Workloads are indexed by the
-- iteration counter so results are NOT memoised, and every result is folded into
-- a checksum that is printed, so the optimiser cannot eliminate the work as dead
-- code. Report relative change against a baseline; absolute ns are machine- and
-- load-dependent.

public export
record BenchmarkResult where
  constructor MkBenchmarkResult
  name       : String
  iterations : Nat
  total_ns   : Integer
  avg_ns     : Integer
  checksum   : Bool

export
Show BenchmarkResult where
  show r =
    name r ++ ": " ++ show (iterations r) ++ " iters, "
    ++ show (total_ns r) ++ " ns total, "
    ++ show (avg_ns r) ++ " ns/iter "
    ++ "[checksum=" ++ show (checksum r) ++ "]"

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

-- Run a named workload `n` times and measure it. The `if` forces the loop's
-- result to be evaluated between the two clock reads.
benchmark : String -> Nat -> (Nat -> Bool) -> IO BenchmarkResult
benchmark nm n f = do
  (chk, elapsed) <- timeIO (if benchLoop n f False then pure True else pure False)
  let avg = if n == 0 then 0 else elapsed `div` cast n
  pure (MkBenchmarkResult nm n elapsed avg chk)

-- =============================================================================
-- WORKLOADS (real, input-dependent functions from the framework)
-- =============================================================================

-- Validate an effect stack of length proportional to i
wlEffects : Nat -> Bool
wlEffects i = effectStackValid (replicate i Read)

-- Check transitivity of equality over index-varied naturals
wlDyadic : Nat -> Bool
wlDyadic i = relationTransitive equalityRelation i (i + 1) (i + 2)

-- Walk a ceremony of length proportional to i to find its terminal step
wlCeremony : Nat -> Bool
wlCeremony i =
  ceremonyEndsProperly (MkCeremony (replicate i (Validate "x") ++ [Complete "done"]))

-- =============================================================================
-- BENCHMARK ENTRY POINT
-- =============================================================================

public export
benchMain : IO ()
benchMain = do
  putStrLn "=== Proven-Tests Benchmark Suite ==="
  putStrLn "(monotonic clock; compare relative change, not absolute ns)"
  putStrLn ""
  let iters = the Nat 2000
  r1 <- benchmark "effectStackValid"     iters wlEffects
  r2 <- benchmark "relationTransitive"   iters wlDyadic
  r3 <- benchmark "ceremonyEndsProperly" iters wlCeremony
  traverse_ (putStrLn . show) [r1, r2, r3]

main : IO ()
main = benchMain
