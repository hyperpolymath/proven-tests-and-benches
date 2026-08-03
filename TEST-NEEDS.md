<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
-->
# TEST-NEEDS: proven-tests-and-benches

**Standard:** [Testing & Benchmarking Taxonomy v1.0.0](https://github.com/hyperpolymath/standards/blob/main/testing-and-benchmarking/TESTING-TAXONOMY.adoc)
**Grading standard:** [Component Readiness Grades v2.2](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)
**Last measured:** 2026-08-03, by a full `scripts/ci-build.sh` run on Idris2 0.7.0.

## Why this file is unusually load-bearing

`TESTING-TAXONOMY.adoc` §Provenance names **this repository** as the first
place every other estate repo must draw tests from — ahead of the standard's
own examples, ahead of a sibling repo, ahead of writing a new one. Whatever is
recorded here as a satisfied category will be *copied outward* and read as
evidence in repositories that never re-examine it.

That makes overclaiming here more expensive than overclaiming anywhere else in
the estate. This file therefore distinguishes three states, and never collapses
the second into the first:

| State | Meaning |
|---|---|
| **REAL** | A test that would fail if the property it names stopped holding. |
| **THIN** | A genuine assertion, but far weaker than the taxonomy's definition of that category. Not a template for other repos. |
| **ABSENT** | Not implemented. Recorded as N/A with justification, per §Scope. |

The taxonomy's own instruction governs the distinction: *"A test written to make
a gate go green, rather than to establish a fact, is worse than no test — it is
read as evidence."*

## Measured state

Verified by running the gate, not by reading a document:

| Quantity | Value | Source |
|---|---|---|
| Framework self-test cells | 36 (35 lattice cells + 1 self-classification) | `src/ProvenTests/Cells.idr` |
| Type-safe category suite | **52 / 52 passing** | `./build/exec/proven-tests-suite`, 2026-08-03 |
| Benchmark harness | runs; 3 workloads, 2000 iterations each | `./benchmarks/build/exec/proven-bench` |
| Category × aspect cells covered | 35 / 238 (14.7%) | `.machine_readable/6a2/STATE.a2ml` |
| Aspect columns non-empty | 14 / 14 | see caveat under Reproducibility below |
| Proof escape hatches | **0** | `just lint`, exit 0 |
| Toolchain pins in agreement | 7 / 7 artefacts + installed compiler | `just check-pins`, exit 0 |

## Category coverage against the 16-category taxonomy

Every category has at least one lattice cell, so the grid reports full category
occupancy. Occupancy is not strength; the Assessment column is what matters.

| # | Category (taxonomy) | Cells | Assessment | Notes |
|---|---|---|---|---|
| 1 | Unit | 1 | REAL | |
| 2 | Point-to-Point | 1 | THIN | One seam only. The repo's real seam — the `integrations/proven` ledger parse — is not exercised in CI (see Gap A). |
| 3 | End-to-End | 2 | REAL | |
| 4 | Build | 2 | REAL | `scripts/ci-build.sh` builds library, suite and benchmark from clean. |
| 5 | Execution & Runtime | 2 | REAL | |
| 6 | Reflexive | 3 | REAL | The framework classifies itself; `Meta.idr` proves the derivation. |
| 7 | Lifecycle | 2 | REAL | |
| 8 | Smoke | 2 | REAL | |
| 9 | Property-Based / Generative | 2 | **THIN** | Properties are evaluated over small *fixed* lists, not generated inputs. Taxonomy expects 1000+ generated cases per property with shrinking and committed regression files. There is no generator and no shrinker. |
| 10 | Mutation | 1 | **THIN** | `mutation-min-distinguished` asserts `oplus (Fin 5) (Fin 2) /= Fin 5` — a single inequality. No source is mutated, no mutants are generated, and no mutation score is computed. Taxonomy target is >80% mutants killed. |
| 11 | Fuzz | 1 | **THIN** | `fuzz-min-le-operand` checks `minN a b <= a` over a fixed `natPairs` list. No random, malformed or adversarial input; nothing can crash. The taxonomy is explicit here: *"No fake fuzz placeholders… A placeholder fuzz file is worse than no fuzz at all."* Recorded as THIN rather than satisfied for exactly that reason. |
| 12 | Contract / Invariant | 2 | THIN | Asserts internal invariants. No contractile files (`Mustfile`, `Trustfile`, K9, ADJUST) exist in this repo to verify, so the taxonomy's actual subject matter is absent. |
| 13 | Regression | 2 | THIN | Assertions are named `regression-*` but are not tied to a fixed bug, issue or commit. Taxonomy expects each fixed bug to become a permanent, traceable test. |
| 14 | Chaos / Resilience | 1 | **THIN** | `chaos-cheapest-with-inf` exercises a `PosInf` value. No failure is injected — no process killed, no data corrupted, no resource exhausted. |
| 15 | Compatibility | 2 | THIN | No versioned artefact or persisted data exists yet to be compatible *with*. |
| 16 | Proof Regression | 1 | REAL | The Idris2 proofs in `Tropical.idr` and `Meta.idr` must typecheck for the build to succeed, so proof breakage genuinely fails the gate. |
| 17 | Type-Safe *(repo-local extension)* | 9 | MIXED | 52/52 assertions pass. Several underlying predicates are `= True` by definition (see Gap B). |

## Aspect coverage

All 14 aspects have at least one covering cell. One of them does not deserve
the credit:

**Reproducibility — the covering cell cannot fail.** `Cells.idr` `reproCell`
binds `run1 = battery` and `run2 = battery` — the *same pure value* — then
reports success when `run1 == run2`. In a pure language that comparison is
true by construction. It is the sole cell covering the Reproducibility aspect,
which means the "14 / 14 aspect columns non-empty" figure in `STATE.a2ml`
depends on it. Treat that figure as 13 / 14 until this cell compares two
genuinely independent executions.

## Gaps, in priority order

### Gap A — the CRG-C evidence never runs
`READINESS.adoc` rests its grade on `integrations/proven/` grading a real
external subject. `scripts/ci-build.sh` runs that step only `if [ -f
"$PROVEN_ROOT/MODULE-STATUS.txt" ]`, defaulting to `/home/user/proven` — a path
that exists on no machine in this estate. A checkout **does** exist at
`hyper-repos/proven`. The step has therefore been skipped on every run, and a
skip is reported as success. The headline evidence for the current grade has
never been produced by the gate that claims it.

### Gap B — vacuous predicates in the type-safe suite
Several predicates the 52 passing assertions rest on are constant functions:
`dependentPairCorrect (MkDepPair _ _) = True`, `vectHeadSafe (x :: _) = True`,
`choreographicNoOrphanedChoices _ = True` for non-`Choice` values. Three of the
four `decorativeTests` entries ignore their argument and re-test a hardcoded
constant. These cannot fail, so they do not discriminate between a working and
a broken implementation. Because other repos are directed to copy from here,
each one is a defect with estate-wide reach.

### Gap C — no benchmark baselines
The taxonomy requires benchmarks be baselined from the mean of the last 10 main
runs, classified on the Six Sigma scale (Unacceptable / Acceptable / Ordinary /
Extraordinary) with defined CI actions, and retained for trend analysis. This
repo has an honest measuring harness — monotonic clock, index-varied workloads,
a checksum to defeat dead-code elimination — and **no baseline, no thresholds,
no history, and no regression gate**. Benchmarks currently print numbers that
nothing compares against. CRG C requires "benchmarks baselined".

### Gap D — the framework's own report is discarded
`Main.idr` calls `runComprehensiveSuiteData`, which prints nothing.
`runComprehensiveSuite`, which prints the per-test lines and the coverage grid,
is never called from anywhere. The coverage map this project is organised
around is computed on every run and thrown away.

### Gap E — categories 9, 10, 11, 14 need real implementations
Property-based testing needs a generator and shrinker; mutation testing needs a
mutant generator and a score; fuzzing needs adversarial input and a crash
oracle; chaos needs actual fault injection. Until then they are THIN above and
must not be copied by other repos as reference implementations.

## What this means for the grade

Against **CRG v2.2** (not the four-rung ladder currently written into
`READINESS.adoc`, which is not the estate standard), grade C requires
"Unit + P2P + E2E + smoke + reflexive + build + contract + aspect tests, all
passing in home context, benchmarks baselined, deep annotation", plus "CI
integration or equivalent automated validation in the home context".

Two of those are not currently met: benchmarks are not baselined (Gap C), and
there is no automated validation on push or PR (the GitHub workflow is
`workflow_dispatch:`-only and no GitLab remote is configured). The grade claim
should be reconciled against the real ladder by the owner rather than adjusted
unilaterally here.
