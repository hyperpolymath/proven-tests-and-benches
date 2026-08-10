<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
-->
# ROADMAP — proven-tests-and-benches

**Written:** 2026-08-07, against `0bc912c`.

Where this repository goes next, in the order that maximises what can be
believed. Every item names its blocker and how you would know it was done —
because "done" claimed without a check is the failure mode this whole project
exists to detect.

Debt IDs refer to [`DEBT.md`](DEBT.md).

## The organising principle

This repository is upstream of the estate's tests. That makes its job **not**
"have lots of tests" but **"be safe to copy from"** — which is a stronger and
narrower requirement. Two consequences drive the ordering below:

1. **A weak test here is worse than a missing one**, because it is copied
   outward and read as evidence in repos that never re-examine it. So honest
   labelling outranks coverage, and removing a claim can be progress.
2. **A gate that has never been seen to fail is not a gate.** Every item below
   is done when its negative test passes, not when its positive test does.

---

## 1 — Make the four THIN categories real

**Why first:** these are the categories most likely to be copied by another repo
looking for a reference implementation, and they are the four furthest from what
the taxonomy actually requires. PR #27 fixed the *labelling*; the labelling was
never the point.

| Category | What the taxonomy requires | What exists |
|---|---|---|
| Property-based | generator, shrinker, committed regression corpus, 1000+ cases | a fixed 4-element list |
| Mutation | generated mutants, kill rate > 80% | one hand-written inequality |
| Fuzz | malformed/adversarial input, crash oracle | five hand-written pairs |
| Chaos | fault injection — killed processes, corrupted data, exhausted resources | one expression containing infinity |

**Order within the item:** property-based first. It is the one with a clean
Idris2 story (a `Gen` type and a shrinker are ordinary code), it produces the
regression corpus the other three benefit from, and it is the category other
repos will reach for most.

**Done when:** each category's cell fails against a deliberately broken
implementation, the mutation score is computed and printed, and the fuzz corpus
is committed. Then, and only then, `TEST-NEEDS.md` moves them from THIN to REAL.

Debt: T-1. Related: T-2 (tie `regression-*` cells to real defects).

## 2 — Two gates the repository claims and does not have

Both are small, both are load-bearing, and both are the *last* things standing
between the current state and a defensible CRG C.

### 2a — Benchmark baselines and a Six Sigma regression gate

The harness is already honest. What is missing is everything that turns a
measurement into a check: machine-readable emission, retained history, a
baseline, thresholds, and something that exits non-zero.

**The trap to avoid.** With no history, σ cannot be computed, so the gate is
mathematically inert until roughly ten runs exist. The tempting move — return
success while bootstrapping — manufactures exactly the fake gate this repository
was built to detect. It must announce its own inertness (`BASELINE
BOOTSTRAPPING: n/10 — gate INERT`, exit 2, the `check-toolchain-pins.sh`
convention for *no check was performed*). And because hosted runners are noisy,
it should fail only on gross regression: a gate that fails randomly gets
disabled, which is its own way of ending up ungated.

**Done when:** an artificial slowdown is classified Unacceptable and fails CI.

Debt: I-1. This is the **last unmet CRG C criterion**.

### 2b — `scripts/check-doc-facts.sh`, the anti-drift gate

**This is the highest-leverage item in the document.** The documentation pass of
2026-08-07 corrected around forty stale statements; without this, the next
merged PR starts the drift again. Re-enabling CI in a single commit previously
falsified six documents at once and none of them noticed for four days.

Compute each fact from its source and compare it against every place it is
asserted:

| Fact | Source of truth |
|---|---|
| library module count | `proven-tests.ipkg` |
| package count | `git ls-files '*.ipkg'` |
| lattice cell count | `cellTests` in `Cells.idr` |
| suite pass counts | the actual run output |
| category × aspect counts | `Types.idr` constructors |
| CRG grade and README badge | `READINESS.adoc`, via `just crg-badge` |

The pattern is already proven here: `check-toolchain-pins.sh` does exactly this
for the Idris2 version across seven artefacts, exits 1 on disagreement and **2**
on a missing declaration, and has been observed failing on injected drift.

**Done when:** injecting a wrong module count into `README.adoc` exits 1, and
changing the grade in `READINESS.adoc` without the badge exits 1.

Debt: D-1, D-2. Also fold in `reuse lint` (L-4) and `pre-commit` (T-4), both
claimed and gated nowhere.

## 3 — Close the panic-attack chain

The Rust side implements this repository's report schema faithfully, field for
field, with passing unit tests. It is reachable from **no CLI flag**, `aggregate`
returns success unconditionally, and the script that would feed it is invoked by
nothing — while `docs/INTEROP-PANIC-ATTACK.adoc` describes the whole thing in
the present tense as working.

Three steps: route the parser to a flag; make `aggregate` exit non-zero on
`Holes`/`Refuted`; invoke `emit-aggregate-inputs.sh` from CI.

**Done when:** a deliberately `Refuted` ladder file fails the build. Until that
has been watched happening, the chain is a description.

Debt: D-5, I-5, S-2.

## 4 — Grow the Actually-Proven tier

2 of 35 lattice cells are Actually-Proven. That tier is the only one that cannot
rot silently — a broken proof stops the build rather than turning a board red —
so it is the only one whose value compounds.

Candidates in rough order of tractability: the coverage-derivation laws (some
already proven in `Meta.idr`), the classification lattice's ordering properties,
and the Baton contract.

**Done when:** each new theorem is cited by a cell whose ladder names it, so the
proof and the test that claims it cannot drift apart.

Debt: P-4.

## 5 — Instantiate or delete the container scaffolding

`container/**` and `.devcontainer/**` are uninstantiated `{{PLACEHOLDER}}`
boilerplate; one file is not even valid TOML un-substituted. More seriously, the
dev container **cannot work**: it runs `just deps` on a Wolfi base image, and
the installer uses `apt-get`. Anyone opening this repository in a dev container
hits that immediately — a bad first experience now that the repo is public.

Deleting is a perfectly good outcome. Scaffolding that has never been
instantiated is not an asset.

Debt: C-2, C-3, C-4, D-9.

## 6 — Release engineering

Now that the repository is public, its absence of release machinery is visible.
`CHANGELOG.md` has a `[0.1.0]` entry and there is **no tag**. No issue or PR
templates, no `SUPPORT.md`, no `CITATION.cff` on a research-adjacent repository
that cites standards.

Tag `v0.1.0` against a commit whose gate is green, then add release automation.

Debt: I-8, I-9, D-6.

## 7 — Decisions the owner owes the repository

These block nothing mechanically and distort the record until settled.

- **Ratify or reject the 17th category.** This repo implements 17; the estate
  standard defines 16; `TypeSafeTest` exists in no standard. Either the standard
  adopts it or this repo marks it a local extension *everywhere* — at present
  only `NEUROSYM.a2ml` says so, while `README.adoc` and `tests/README.adoc`
  imply the standard defines 17. (S-4)
- **Re-score the CRG.** Two of the three blockers to a defensible C are cleared;
  benchmarks remain. Held at C pending item 2a. (D-2)
- **Rule on `ZigzagTests.idr`.** It defines a second `Aspect` type and a second
  Zigzag model. Reconcile, rename, or drop — but not silently land. (C-1)
- **The unused AGPL licence file.** Removing a file from `LICENSES/` is a
  licensing action. (L-1)

## Not on this roadmap, deliberately

**`echo-types` — `Safety.idr` and `Invariance.idr` stay unwritten** (updated
2026-08-10: upstream now has ~205 proved Agda modules, so the old "no formal
artefacts" rationale is stale — but none are Idris2, so the semantics are still
not *citable* from here without a port, and inventing an unfaithful Idris2
rendering would produce modules that compile, pass, and mean nothing). The reasoning
is recorded in `src/ProvenTests/EchoTypes/README.adoc`, which is worth reading
as a model for leaving something undone on purpose.

That is the whole argument of this repository, applied to itself: an honest
absence beats a green placeholder, because only one of them can mislead you.
