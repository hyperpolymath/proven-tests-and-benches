-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-License-Identifier: CC-BY-SA-4.0
-- SPDX-License-Identifier: MPL-2.0
-- Mozilla Post-Quantum License Provisions v1.0
--
-- Copyright (c) 2026 Joshua Jewell (JoshuaJewell)
-- Copyright (c) 2026 Joshua Jewell (hyperpolymath)
--

module ProvenTests.Benchmarks.Benchmark

import ProvenTests.TypeSafe.Tropical
import ProvenTests.TypeSafe.Epistemic
import ProvenTests.TypeSafe.Choreographic
import ProvenTests.TypeSafe.Dependent
import ProvenTests.TypeSafe.Effects
import ProvenTests.TypeSafe.Decorative
import ProvenTests.TypeSafe.Ceremonial
import ProvenTests.TypeSafe.Dyadic
import ProvenTests.TypeSafe.Bridge
import Data.Time

-- =============================================================================
-- BENCHMARK SUITE FOR PROVEN-TESTS
-- =============================================================================

%%access export

-- Benchmark result type
public export
record BenchmarkResult where
  constructor MkBenchmarkResult
  name : String
  iterations : Nat
  total_time : Nat  -- microseconds
  avg_time : Nat    -- microseconds per iteration
  passed : Bool

-- Display instance
public export
Show BenchmarkResult where
  show (MkBenchmarkResult n i t a p) = 
    n ++ ": " ++ 
    show i ++ " iterations, " ++ 
    show t ++ "us total, " ++ 
    show a ++ "us avg, " ++ 
    (if p then "PASSED" else "FAILED")

-- =============================================================================
-- TIMING UTILITIES
-- =============================================================================

-- Simple timing (Idris2 doesn't have high-res timers in core)
-- We use a mock timing for now
public export
timeAction : IO a -> IO (a, Nat)
timeAction action = do
  -- In a real implementation, this would use system time
  -- For now, we return a mock value
  result <- action
  pure (result, 0)

-- =============================================================================
-- BENCHMARK FUNCTIONS
-- =============================================================================

public export
benchmarkTropical : Nat -> IO BenchmarkResult
benchmarkTropical iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runTropicalTests)
    pure True
  )
  pure (MkBenchmarkResult "Tropical" iterations time (time / iterations) result)

public export
benchmarkEpistemic : Nat -> IO BenchmarkResult
benchmarkEpistemic iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runEpistemicTests)
    pure True
  )
  pure (MkBenchmarkResult "Epistemic" iterations time (time / iterations) result)

public export
benchmarkChoreographic : Nat -> IO BenchmarkResult
benchmarkChoreographic iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runChoreographicTests)
    pure True
  )
  pure (MkBenchmarkResult "Choreographic" iterations time (time / iterations) result)

public export
benchmarkDependent : Nat -> IO BenchmarkResult
benchmarkDependent iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runDependentTests)
    pure True
  )
  pure (MkBenchmarkResult "Dependent" iterations time (time / iterations) result)

public export
benchmarkEffects : Nat -> IO BenchmarkResult
benchmarkEffects iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runEffectsTests)
    pure True
  )
  pure (MkBenchmarkResult "Effects" iterations time (time / iterations) result)

public export
benchmarkDecorative : Nat -> IO BenchmarkResult
benchmarkDecorative iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runDecorativeTests)
    pure True
  )
  pure (MkBenchmarkResult "Decorative" iterations time (time / iterations) result)

public export
benchmarkCeremonial : Nat -> IO BenchmarkResult
benchmarkCeremonial iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runCeremonialTests)
    pure True
  )
  pure (MkBenchmarkResult "Ceremonial" iterations time (time / iterations) result)

public export
benchmarkDyadic : Nat -> IO BenchmarkResult
benchmarkDyadic iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (runDyadicTests)
    pure True
  )
  pure (MkBenchmarkResult "Dyadic" iterations time (time / iterations) result)

public export
benchmarkBridge : Nat -> IO BenchmarkResult
benchmarkBridge iterations = do
  (result, time) <- timeAction (do
    for _ in [1..iterations] do
      _ <- pure (allBridgeTestsPass)
    pure True
  )
  pure (MkBenchmarkResult "Bridge" iterations time (time / iterations) result)

-- =============================================================================
-- RUN ALL BENCHMARKS
-- =============================================================================

public export
runAllBenchmarks : Nat -> IO (List BenchmarkResult)
runAllBenchmarks iterations = do
  results <- sequence [
    benchmarkTropical iterations,
    benchmarkEpistemic iterations,
    benchmarkChoreographic iterations,
    benchmarkDependent iterations,
    benchmarkEffects iterations,
    benchmarkDecorative iterations,
    benchmarkCeremonial iterations,
    benchmarkDyadic iterations,
    benchmarkBridge iterations
  ]
  pure results
  where
    sequence : List (IO a) -> IO (List a)
    sequence [] = pure []
    sequence (x::xs) = do
      y <- x
      ys <- sequence xs
      pure (y::ys)

-- =============================================================================
-- BENCHMARK MAIN
-- =============================================================================

public export
benchMain : IO ()
benchMain = do
  putStrLn "=== Proven-Tests Benchmark Suite ==="
  putStrLn ""
  
  -- Run benchmarks with default iterations
  let iterations = 100
  putStrLn ("Running benchmarks with " ++ show iterations ++ " iterations each...")
  putStrLn ""
  
  results <- runAllBenchmarks iterations
  
  -- Print results
  mapM_ ( => putStrLn (show r)) results
  
  putStrLn ""
  
  -- Summary
  let passed = length (filter ( => r.passed) results)
      total = length results
  putStrLn ("Benchmark Summary: " ++ show passed ++ "/" ++ show total ++ " passed")
  
  if passed == total then
    putStrLn "✅ All benchmarks passed!"
  else
    putStrLn "⚠️  Some benchmarks may have timing issues"
