<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
-->
# TEST-NEEDS: proven-tests-and-benches

**Standard:** [Testing & Benchmarking Taxonomy v1.0.0](https://github.com/hyperpolymath/standards/blob/main/testing-and-benchmarking/TESTING-TAXONOMY.adoc)
**Grading standard:** [Component Readiness Grades v2.2](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)
**Last measured:** 2026-08-07, by a full `scripts/ci-build.sh` run (exit 0) on
Idris2 0.7.0, plus `just test-spec`.

> Every figure below dated 2026-08-03 predated PRs #20-#26 (HigherOrder and
> SetTheory suites, AffineScript borrow modelling, the 12 Actually-Proven
> theorems, the secret scanner). They have been re-measured.

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

Admissibility is governed by [`docs/TEST-DOCTRINE.adoc`](docs/TEST-DOCTRINE.adoc)
(harness/payload separation, silence + firing fixtures); grading below is about
strength, and the taxonomy's own instruction governs the distinction: *"A test written to make
a gate go green, rather than to establish a fact, is worse than no test — it is
read as evidence."*

## Measured state

Verified by running the gate, not by reading a document:

| Quantity | Value | Source |
|---|---|---|
| Framework self-test cells | 41 (40 lattice cells + 1 self-classification) | `src/ProvenTests/Cells.idr` |
| Type-safe category suite | **56 / 56 passing** | `./build/exec/proven-tests-suite`, 2026-08-07 |
| Spec suite (Proven laws, AffineScript, HigherOrder, SetTheory) | **75 / 75 passing**, of which **12 report Actually-Proven** | `./build/exec/proven-spec-suite`, 2026-08-07 — first gated run |
| Benchmark harness | runs; 4 workloads, 5 samples each, calibrated iteration counts, `--json` emission | `./benchmarks/build/exec/proven-bench --json`, 2026-08-10 |
| Category × aspect cells covered | 40 / 238 (16.8%) | `./build/exec/proven-tests` run output, 2026-08-10 |
| Aspect columns non-empty | **14 / 14**, and now truthfully | `./build/exec/proven-tests`; the Reproducibility caveat below is resolved |
| Proof escape hatches | **0** | `just lint`, exit 0 |
| Toolchain pins in agreement | 7 / 7 artefacts + installed compiler | `just check-pins`, exit 0 |

## Category coverage against the 16-category taxonomy

Every category has at least one lattice cell, so the grid reports full category
occupancy. Occupancy is not strength; the Assessment column is what matters.

| # | Category (taxonomy) | Cells | Assessment | Notes |
|---|---|---|---|---|
| 1 | Unit | 3 | REAL | +2 boundary cells (empty report, empty coverage) salvaged 2026-08-10. |
| 2 | Point-to-Point | 1 | THIN | One seam only. The repo's real seam — the `integrations/proven` ledger parse — is not exercised in CI (see Gap A). |
| 3 | End-to-End | 2 | REAL | |
| 4 | Build | 2 | REAL | `scripts/ci-build.sh` builds library, suite and benchmark from clean. |
| 5 | Execution & Runtime | 2 | REAL | |
| 6 | Reflexive | 6 | REAL | The framework classifies itself; `Meta.idr` proves the derivation. +3 classify→isX round-trip cells (salvaged 2026-08-10; originally mislabelled P2P — a round-trip of the framework's own machinery is reflexive). |
| 7 | Lifecycle | 2 | REAL | |
| 8 | Smoke | 2 | REAL | |
| 9 | Property-Based / Generative | 2 | **THIN** | Properties are evaluated over small *fixed* lists, not generated inputs. Taxonomy expects 1000+ generated cases per property with shrinking and committed regression files. There is no generator and no shrinker. |
| 10 | Mutation | 1 | **THIN** | `mutation-single-handwritten-mutant` (renamed from `mutation-min-distinguished`) asserts `oplus (Fin 5) (Fin 2) /= Fin 5` — a single inequality. No source is mutated, no mutants are generated, and no mutation score is computed. Taxonomy target is >80% mutants killed. |
| 11 | Fuzz | 1 | **THIN** | `fuzz-fixed-vectors-min-le-operand` (renamed from `fuzz-min-le-operand`) checks `minN a b <= a` over a fixed `natPairs` list. No random, malformed or adversarial input; nothing can crash. The taxonomy is explicit here: *"No fake fuzz placeholders… A placeholder fuzz file is worse than no fuzz at all."* Recorded as THIN rather than satisfied for exactly that reason. |
| 12 | Contract / Invariant | 2 | THIN | Asserts internal invariants. No contractile files (`Mustfile`, `Trustfile`, K9, ADJUST) exist in this repo to verify, so the taxonomy's actual subject matter is absent. |
| 13 | Regression | 2 | THIN | Assertions are named `regression-*` but are not tied to a fixed bug, issue or commit. Taxonomy expects each fixed bug to become a permanent, traceable test. |
| 14 | Chaos / Resilience | 1 | **THIN** | `chaos-inf-propagation-only` (renamed from `chaos-cheapest-with-inf`) exercises a `PosInf` value. No failure is injected — no process killed, no data corrupted, no resource exhausted. |
| 15 | Compatibility | 2 | THIN | No versioned artefact or persisted data exists yet to be compatible *with*. |
| 16 | Proof Regression | 1 | REAL | The Idris2 proofs in `Tropical.idr` and `Meta.idr` must typecheck for the build to succeed, so proof breakage genuinely fails the gate. |
| 17 | Type-Safe *(repo-local extension)* | 9 | MIXED | 56/56 assertions pass. The vacuous predicates recorded in Gap B are fixed (PR #27) and negative fixtures added; the remaining `= True` cases in `Dependent.idr` are true *by type index*, and are now labelled as type-level guarantees rather than runtime tests. |

## Aspect coverage

All 14 aspects have at least one covering cell. One of them does not deserve
the credit:

**Reproducibility — RESOLVED 2026-08-07 (PR #27).** This section previously
read: *"the covering cell cannot fail… treat that figure as 13 / 14"*. It is
kept here in corrected form because the defect is instructive.

`Cells.idr` `reproCell` bound `run1 = battery` and `run2 = battery` — two names
for the *same pure value* — then reported success when `run1 == run2`. In a pure
language that is reflexivity: true by construction, with the `Failed` branch
unreachable. It was the sole cell covering the Reproducibility aspect, so
`STATE.a2ml`'s `aspect-columns-nonempty = "14 / 14"` rested entirely on a cell
that could not fail.

The cell now runs the battery at two *different* workload sizes. Every predicate
in it is invariant in that size — ⊕ is min and ⊗ (Fin k) (Fin 1) = Fin (k+1), so
the fold's minimum sits at k = 1 for every n ≥ 1 — which makes agreement a real
property rather than an identity, and makes the two executions impossible to
collapse into one shared thunk.

Verified by injecting a size-dependent predicate: the cell reported `Failed` and
the executable exited 1. **14 / 14 is now earned.**

## Gaps, in priority order

### Gap F — the strongest evidence in the repository was gated by nothing

**Closed 2026-08-07 (PR #27).** `proven-spec-suite.ipkg` carries 75 tests across
`ProvenLawsTests`, `AffineScriptTests`, `HigherOrderTests` and `SetTheoryTests`
— including the **12 Actually-Proven theorems** that `PROOFS.adoc:134` headlines
as this repository's top-tier claim. It was built by no `just` recipe, no line of
`scripts/ci-build.sh`, and no workflow step. Nothing had ever confirmed those
theorems still compile.

This outranked Gaps A-E while it was open. The Actually-Proven tier is the one
that *cannot* rot silently — a broken proof stops the build — but only if
something builds it. An ungated proof suite has the failure mode of a
documentation claim, not of a proof.

It now runs in `just ci`, `just test` and `just test-spec`. First gated run:
75/75, with exactly 12 reporting `[Actually-Proven]`, corroborating the
documented figure precisely. The claim was true; nothing had checked it.

**Rule this generalises to:** if you add a package, add it to the gate in the
same commit. A suite nothing runs is indistinguishable from one that does not
exist — except that it looks like coverage.

### Gap A — the CRG-C evidence never runs

**CLOSED.** `scripts/ci-build.sh:55-67` now searches the paths a sibling checkout
actually occupies, and `ci.yml` clones the subject. Verified running in CI on
2026-08-07: 0 Actually / 41 Provisionally / 47 Unproven, reproducing
`STATE.a2ml` exactly. It remains `continue-on-error`, so it informs and does not
gate. The original analysis follows.
`READINESS.adoc` rests its grade on `integrations/proven/` grading a real
external subject. `scripts/ci-build.sh` runs that step only `if [ -f
"$PROVEN_ROOT/MODULE-STATUS.txt" ]`, defaulting to `/home/user/proven` — a path
that exists on no machine in this estate. A checkout **does** exist at
`hyper-repos/proven`. The step has therefore been skipped on every run, and a
skip is reported as success. The headline evidence for the current grade has
never been produced by the gate that claims it.

### Gap B — vacuous predicates in the type-safe suite

**CLOSED 2026-08-07 (PR #27).** Fixed in `Dyadic.idr`, `Choreographic.idr`,
`Decorative.idr` and `Dependent.idr`, with negative fixtures added throughout so
that a checker returning `True` constantly can no longer pass. The suite went
52/52 → 56/56. The original analysis follows.

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

**CLOSED 2026-08-07 (PR #27).** `runComprehensiveSuite` (the printing runner) had
zero call sites; `Main.idr` called the silent variant. Running and printing are
now separated rather than duplicated, so the 17×14 grid prints on every run.
`--quiet` restores the old silence for scripted use. The original analysis follows.

`Main.idr` calls `runComprehensiveSuiteData`, which prints nothing.
`runComprehensiveSuite`, which prints the per-test lines and the coverage grid,
is never called from anywhere. The coverage map this project is organised
around is computed on every run and thrown away.

### Gap E — categories 9, 10, 11, 14 need real implementations
Property-based testing needs a generator and shrinker; mutation testing needs a
mutant generator and a score; fuzzing needs adversarial input and a crash
oracle; chaos needs actual fault injection. Until then they are THIN above and
must not be copied by other repos as reference implementations.

**Partially addressed 2026-08-07 (PR #27)** — the *labelling*, not the
implementations. All five cells used the `pc` constructor, stamping them
ProvisionallyProven with a TypeSafetyCertificate at Kategoria level 6, which a
fixed five-element vector cannot support. They are now `uc` (Unproven) and
renamed to state what they actually assert:

| Was | Now |
|---|---|
| `prop-oplus-comm` | `prop-fixed-vectors-oplus-comm` |
| `prop-oplus-idem` | `prop-fixed-vectors-oplus-idem` |
| `mutation-min-distinguished` | `mutation-single-handwritten-mutant` |
| `fuzz-min-le-operand` | `fuzz-fixed-vectors-min-le-operand` |
| `chaos-cheapest-with-inf` | `chaos-inf-propagation-only` |

The tier now shows in the run output as `[Unproven]`, so the weakness is visible
where a reader actually looks rather than only in this file. The four categories
remain **THIN**. Building them properly is `ROADMAP.md` item 1.

## What this means for the grade

Against **CRG v2.2** (not the four-rung ladder currently written into
`READINESS.adoc`, which is not the estate standard), grade C requires
"Unit + P2P + E2E + smoke + reflexive + build + contract + aspect tests, all
passing in home context, benchmarks baselined, deep annotation", plus "CI
integration or equivalent automated validation in the home context".

**One** of those is not currently met: benchmarks are not baselined (Gap C).

Automated validation on push and PR **is** now met — `ci.yml` has run on
`push` and `pull_request` since 2026-08-03 and CodeQL was restored to the same
triggers on 2026-08-07. This paragraph asserted the opposite until 2026-08-07,
and so did `READINESS.adoc:50-52`, `docs/ZERO-MINUTE-CI.adoc`,
`docs/STATE-OF-THINGS.adoc` and `CHANGELOG.md` — five documents falsified by
one commit, none of which noticed. See `DEBT.md` D-1.

The grade claim should still be reconciled against the real ladder by the owner
rather than adjusted unilaterally here.
