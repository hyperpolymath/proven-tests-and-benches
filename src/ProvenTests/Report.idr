-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenTests.Report

import ProvenTests.Types
import ProvenTests.Classification
import ProvenTests.Taxonomy
import ProvenTests.Framework
import Data.List
import Data.List1
import Data.String

-- =============================================================================
-- REPORT DATA STRUCTURES
-- =============================================================================

--/ A test execution report
public export
record TestReport where
  constructor MkTestReport
  
  test_metadata : TestMetadata
  result        : TestResult
  timestamp     : String
  duration_ms   : Maybe Nat

--/ A full test suite report
public export
record SuiteReport where
  constructor MkSuiteReport
  
  suite_name  : String
  tests       : List TestReport
  start_time  : String
  end_time    : String
  total_tests : Nat
  passed       : Nat
  failed       : Nat
  errors       : Nat
  skipped      : Nat

--/ Classification summary
public export
record ClassificationSummary where
  constructor MkClassificationSummary
  
  actually_proven     : Nat
  provisionally_proven : Nat
  unproven           : Nat
  totalCount              : Nat

-- =============================================================================
-- REPORT GENERATION
-- =============================================================================

--/ Generate a test report from metadata and result
public export
generateTestReport : TestMetadata -> TestResult -> String -> Maybe Nat -> TestReport
generateTestReport meta result timestamp duration =
  MkTestReport meta result timestamp duration

--/ Count test results as (passed, failed, errors, skipped)
public export
countResults : List TestReport -> (Nat, Nat, Nat, Nat)
countResults reports = foldl countOne (0, 0, 0, 0) reports
  where
    countOne : (Nat, Nat, Nat, Nat) -> TestReport -> (Nat, Nat, Nat, Nat)
    countOne (p, f, e, s) r = case result r of
      Passed => (p + 1, f, e, s)
      Failed _ => (p, f + 1, e, s)
      Error _ => (p, f, e + 1, s)
      Skipped _ => (p, f, e, s + 1)

-- =============================================================================
-- CLASSIFICATION SUMMARY
-- =============================================================================

--/ Generate classification summary from list of reports
public export
generateClassificationSummary : List TestReport -> ClassificationSummary
generateClassificationSummary reports =
  let (act, prov, unprov) = foldl classifyOne (0, 0, 0) reports
  in MkClassificationSummary act prov unprov (act + prov + unprov)
  where
    classifyOne : (Nat, Nat, Nat) -> TestReport -> (Nat, Nat, Nat)
    classifyOne (a, p, u) r = case getProvenStatus (test_metadata r) of
      ActuallyProven => (a + 1, p, u)
      ProvisionallyProven => (a, p + 1, u)
      Unproven => (a, p, u + 1)

-- =============================================================================
-- JSON OUTPUT
-- =============================================================================

--/ Convert a TestReport to a JSON-like string (simplified)
public export
testReportToJSON : TestReport -> String
testReportToJSON (MkTestReport meta result timestamp duration) =
  "{" ++
  "\"test_id\":\"" ++ show (test_id meta) ++ "\"," ++
  "\"status\":\"" ++ show (getProvenStatus meta) ++ "\"," ++
  "\"result\":\"" ++ show result ++ "\"," ++
  "\"timestamp\":\"" ++ timestamp ++ "\"" ++
  (case duration of
     Just d => ",\"duration_ms\":" ++ show d
     Nothing => "") ++
  "}"

--/ Convert a ClassificationSummary to JSON-like string
public export
classificationSummaryToJSON : ClassificationSummary -> String
classificationSummaryToJSON (MkClassificationSummary act prov unprov totalCount) =
  "{" ++
  "\"actually_proven\":" ++ show act ++ "," ++
  "\"provisionally_proven\":" ++ show prov ++ "," ++
  "\"unproven\":" ++ show unprov ++ "," ++
  "\"total\":" ++ show totalCount ++
  "}"

-- =============================================================================
-- MAIN REPORT GENERATOR
-- =============================================================================

--/ Generate a full report from test results
public export
generateFullReport : List TestReport -> String -> String -> SuiteReport
generateFullReport reports start end =
  let (passed, failed, errors, skipped) = countResults reports
      totalCount = length reports
      class_summary = generateClassificationSummary reports
  in MkSuiteReport "Proven-Tests" reports start end totalCount passed failed errors skipped

--/ Print a full report
public export
printReport : SuiteReport -> IO ()
printReport (MkSuiteReport name tests start end totalCount p f e s) = do
  putStrLn ""
  putStrLn "=== PROVEN-TESTS REPORT ==="
  putStrLn ""
  putStrLn ("Suite: " ++ name)
  putStrLn ("Start: " ++ start)
  putStrLn ("End: " ++ end)
  putStrLn ""
  putStrLn "--- Summary ---"
  putStrLn ("Total: " ++ show totalCount)
  putStrLn ("Passed: " ++ show p ++ " ")
  putStrLn ("Failed: " ++ show f ++ " ")
  putStrLn ("Errors: " ++ show e ++ " ")
  putStrLn ("Skipped: " ++ show s)
  
  -- Print classification summary
  let class_sum = generateClassificationSummary tests
  putStrLn ""
  putStrLn "--- Classification ---"
  putStrLn ("Actually-Proven: " ++ show (actually_proven class_sum))
  putStrLn ("Provisionally-Proven: " ++ show (provisionally_proven class_sum))
  putStrLn ("Unproven: " ++ show (unproven class_sum))
  
  putStrLn ""
  putStrLn "=== END REPORT ==="

-- =============================================================================
-- MACHINE-READABLE RUN REPORT (schema_version 1)
-- =============================================================================
-- A stable JSON document describing a run: per-test provenance (with proof
-- ladders for Actually-Proven tests) plus a coverage summary. This is the
-- estate-interop surface — panic-attack's `aggregate` folds the cited proof
-- ladder files in (see docs/INTEROP-PANIC-ATTACK.adoc). Hand-rolled encoder;
-- our string values are known-safe (identifiers, digits, file paths).

jstr : String -> String
jstr s = "\"" ++ s ++ "\""

jmaybeCat : Maybe TestCategory -> String
jmaybeCat Nothing  = "null"
jmaybeCat (Just c) = jstr (show c)

jmaybeAsp : Maybe TestAspect -> String
jmaybeAsp Nothing  = "null"
jmaybeAsp (Just a) = jstr (show a)

--/ The proof ladder behind a provenance (empty unless Actually-Proven).
ladderOf : Provenance -> List ProofStep
ladderOf (PActuallyProven ev) = forget (proof_ladder ev)
ladderOf _                    = []

proofStepJSON : ProofStep -> String
proofStepJSON (MkProofStep desc file _ thm) =
  "{" ++ jstr "description" ++ ":" ++ jstr desc
      ++ "," ++ jstr "proof_file" ++ ":" ++ (maybe "null" jstr file)
      ++ "," ++ jstr "theorem" ++ ":" ++ (maybe "null" jstr thm)
      ++ "}"

resultJSON : TestResult -> String
resultJSON Passed        = jstr "passed"
resultJSON (Failed m)    = "{" ++ jstr "failed"  ++ ":" ++ jstr m ++ "}"
resultJSON (Error m)     = "{" ++ jstr "error"   ++ ":" ++ jstr m ++ "}"
resultJSON (Skipped m)   = "{" ++ jstr "skipped" ++ ":" ++ jstr m ++ "}"

--/ One test entry: id, coordinate axes, provenance tier + ladder, result.
entryJSON : (TestMetadata, TestResult) -> String
entryJSON (m, r) =
  let ladder = ladderOf (provenance m)
  in "{" ++ jstr "test_id" ++ ":" ++ jstr (show (test_id m))
        ++ "," ++ jstr "category" ++ ":" ++ jmaybeCat (category m)
        ++ "," ++ jstr "aspect" ++ ":" ++ jmaybeAsp (aspect m)
        ++ "," ++ jstr "provenance" ++ ":" ++ jstr (show (getProvenStatus m))
        ++ "," ++ jstr "proof_ladder" ++ ":["
             ++ concat (intersperse "," (map proofStepJSON ladder)) ++ "]"
        ++ "," ++ jstr "result" ++ ":" ++ resultJSON r
        ++ "}"

entryPassed : (TestMetadata, TestResult) -> Bool
entryPassed (_, Passed) = True
entryPassed _           = False

toReport : (TestMetadata, TestResult) -> TestReport
toReport (m, r) = MkTestReport m r "" Nothing

--/ The full run report. Takes the run entries and the coverage triple
--/ (covered category x aspect cells, total such cells, full-lattice covered).
public export
runReportJSON : List (TestMetadata, TestResult) -> (Nat, Nat, Nat) -> String
runReportJSON entries (coveredCells, totalCells, latticeCovered) =
  "{" ++ jstr "schema_version" ++ ":1"
      ++ "," ++ jstr "suite" ++ ":" ++ jstr "proven-tests"
      ++ "," ++ jstr "summary" ++ ":{"
           ++ jstr "passed" ++ ":" ++ show (length (filter entryPassed entries))
           ++ "," ++ jstr "total" ++ ":" ++ show (length entries)
           ++ "," ++ jstr "actually_proven" ++ ":" ++ show (actually_proven cs)
           ++ "," ++ jstr "provisionally_proven" ++ ":" ++ show (provisionally_proven cs)
           ++ "," ++ jstr "unproven" ++ ":" ++ show (unproven cs)
           ++ "," ++ jstr "covered_cells" ++ ":" ++ show coveredCells
           ++ "," ++ jstr "cat_aspect_cells" ++ ":" ++ show totalCells
           ++ "," ++ jstr "lattice_covered" ++ ":" ++ show latticeCovered
           ++ "}"
      ++ "," ++ jstr "entries" ++ ":["
           ++ concat (intersperse "," (map entryJSON entries)) ++ "]"
      ++ "}\n"
  where
    cs : ClassificationSummary
    cs = generateClassificationSummary (map toReport entries)
