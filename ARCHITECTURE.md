<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
-->
# Architecture

> Rewritten 2026-08-03. The previous version was donor-template boilerplate:
> it described a `config/` directory that does not exist, never mentioned
> Idris2, and omitted `benchmarks/`, `integrations/` and `.machine_readable/`.
> Nothing in it was specific to this repository.

## What this repository is

An Idris2 testing and benchmarking framework whose organising idea is that a
test's **warrant** — the strength of the evidence behind it — is a first-class,
machine-checked value rather than a label someone attached.

Two structural commitments follow from that, and everything else is downstream
of them:

1. **A provenance tier cannot be claimed without its evidence.** The
   `Actually-Proven` constructor requires a non-empty proof ladder as a typed
   field, so the state "Actually-Proven, zero proof steps" cannot be
   constructed. This is enforced by the type system, not by review.

2. **Coverage is derived, never asserted.** A cell in the coverage grid is
   marked covered because a test at that typed coordinate ran and passed. The
   derivation itself is proved, so the grid cannot be hand-edited into looking
   better than it is.

## Directory structure

```
.
├── src/ProvenTests/            # The framework library (32 modules)
│   ├── Types.idr               # Provenance, TestCategory, TestAspect, evidence records
│   ├── Tropical.idr            # Min-plus semiring + its laws, proved total
│   ├── Coverage.idr            # Derives the coverage grid from executed tests
│   ├── Meta.idr                # Proves the derivation in Coverage.idr is sound
│   ├── Cells.idr               # The 40 lattice cells + 1 self-classification
│   ├── Zigzag.idr              # The 3570-coordinate lattice
│   ├── Runners.idr             # Suite execution
│   ├── Report.idr              # JSON run report, schema_version 1
│   └── TypeSafe/               # 9 category-specific property modules
├── tests/TypeSafeTests/        # The 52-assertion type-safe suite (separate package)
├── benchmarks/                 # Timing harness (monotonic clock, DCE-defeated)
├── integrations/proven/        # Grades an EXTERNAL subject from its own ledgers
├── scripts/                    # Toolchain install, CI gate, pin check, gate wiring
├── docs/                       # Design and self-audit documents
├── .machine_readable/6a2/      # The 6 A2ML metadata files
├── .well-known/                # security.txt, ai.txt, humans.txt
├── container/                  # UNINSTANTIATED template — not wired to anything
└── .devcontainer/              # UNINSTANTIATED template
```

`container/` and `.devcontainer/` still contain `{{PLACEHOLDER}}` tokens and are
not referenced by any pipeline. `container/README.adoc` says so itself. They are
listed here so their presence is not mistaken for working infrastructure.

## The five packages

This repository builds **five** Idris2 packages, not one. They are separate
because the dependency direction matters:

| Manifest | Produces | Depends on |
|---|---|---|
| `proven-tests.ipkg` | the library + `proven-tests` executable | — |
| `proven-tests-suite.ipkg` | `proven-tests-suite` (52 assertions) | the installed library |
| `benchmarks/benchmark.ipkg` | `proven-bench` | the installed library |
| `integrations/proven/proven-subject.ipkg` | `proven-subject-report` | the installed library |

The suite builds *against the installed library* rather than against the source
tree. That is deliberate: it means the suite exercises the library as a consumer
would receive it, so a module missing from the `.ipkg` module list fails the
suite build rather than silently working from source.

## Data flow

```
  Cells.idr ──┐
              ├─→ Runners ──→ TestResult[] ──→ Coverage.coveredFrom ──→ grid
  TypeSafe/ ──┘                    │                   ↑
                                   │            Meta.idr proves this
                                   ↓            derivation is sound
                              Report.idr
                                   │
                                   ↓
                   JSON run report (schema_version 1)
                                   │
                                   ↓
                    panic-attack `aggregate`  ← PARTIAL (see below)
```

## External integration

**panic-attack** is the intended downstream consumer. The state of that
integration is two-sided and should not be described as done:

- *Ladder-file aggregation* works. `scripts/emit-aggregate-inputs.sh` feeds
  cited proof files to `panic-attack aggregate --proof/--label`; `.idr` is a
  first-class prover input there. **But** `aggregate` never exits non-zero on a
  bad verdict, so the CI gate the design assumes cannot actually fail, and no
  workflow or `just` recipe invokes the script.
- *Native run-report ingestion* does not work. `panic-attack`'s
  panic-attack's `src/aggregate/proven_tests.rs` (in the `panic-attack` repo, not this tree) parses this repo's report schema correctly
  and is unit-tested, but it is declared once in `aggregate/mod.rs` and reachable
  from no CLI flag.

`integrations/proven/` grades the `proven` repository from its own
`MODULE-STATUS.txt` and OWED ledger, without re-checking its proofs. It is
skipped whenever no `proven` checkout is found — and the default search path
points at a directory that exists on no machine in this estate.

## Design principles that are actually enforced

- **No proof escape hatches.** `believe_me`, `assert_total`, `%partial`,
  `idris_crash` and `unsafePerformIO` appear nowhere in the Idris2 sources.
  `just lint` fails on any of them.
- **Totality where it carries weight.** `%default total` is set in `Tropical`,
  `Coverage`, `Meta`, `Baton`, `GoldenVectors`, `Grading` and `Ledger`.
- **One toolchain version.** Seven artefacts name an Idris2 version;
  `scripts/check-toolchain-pins.sh` fails if any disagree.
- **Typed taxonomy axes.** Categories and aspects are enums, not strings, so
  metadata can only name a coordinate that exists.

## Known architectural defects

Recorded here rather than in a private list, because they change how the code
should be read:

- **The report is computed and discarded.** `Main.idr` calls the silent runner;
  the printing runner is never called from anywhere. The coverage grid this
  whole design produces is thrown away on every run.
- **The Reproducibility cell cannot fail.** It compares a pure binding with
  itself. It is the only cell covering that aspect.
- **Several type-safe predicates are constant functions** returning `True`
  regardless of input, so the assertions resting on them cannot discriminate a
  working implementation from a broken one.

See `TEST-NEEDS.md` for the full gap analysis and `docs/STATE-OF-THINGS.adoc`
for the standing self-audit.
