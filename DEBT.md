<!--
SPDX-License-Identifier: CC-BY-SA-4.0
SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
-->
# DEBT — proven-tests-and-benches

**Compiled:** 2026-08-07, against `0bc912c`; **last re-measured 2026-08-10** (I-10
added; I-3/I-4/I-7 remain closed). The register holds **45 items** — a figure now
GATED by `scripts/check-doc-facts.sh`, because the original header claimed 36 while
the tables held 44 and nothing noticed for three days.
**Method:** every item below carries the command that produced its evidence.
Anything not confirmed by running something is labelled **DIAGNOSIS
(unconfirmed)** and is not asserted.

This file is an **index**. It links to the existing registers rather than
duplicating them — [`TEST-NEEDS.md`](TEST-NEEDS.md) for category-level test debt,
[`PROOFS.adoc`](PROOFS.adoc) for the proof catalogue, [`READINESS.adoc`](READINESS.adoc)
for the grade and its evidence, and the "Known architectural defects" section of
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Why this repository keeps a debt register at all

The estate testing standard names this repository as the **first** place every
other repo must draw tests from. A weakness here is copied outward wearing the
authority of the canonical source. Recording debt explicitly is cheaper than
having it inferred from a green board — and a green board is exactly what this
repository had while five of the defects below were live.

**Severity** is about blast radius, not effort:
**HIGH** — actively misleads a reader, or a gate that cannot fail.
**MEDIUM** — real gap, correctly described somewhere.
**LOW** — tidiness, or a decision deferred on purpose.

---

## Licence — L

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **L-1** | LOW | `LICENSES/AGPL-3.0-or-later.txt` is unused; no file declares AGPL. `reuse lint` reports one issue forever because of it. | `reuse lint` → `Unused licenses: AGPL-3.0-or-later` | **Owner only.** Removing a file from `LICENSES/` is a licensing action. Deliberately not actioned. |
| **L-2** | LOW | `LICENSE` is not byte-identical to `LICENSES/MPL-2.0.txt` — a trailing space on line 38 and `http` vs `https` on line 360. | `diff LICENSE LICENSES/MPL-2.0.txt` | Add an `exclude:` for `LICENSE` to the `trailing-whitespace` pre-commit hook. That hook would otherwise silently rewrite licence text, which `AGENTS.md:15` forbids. |
| **L-3** | MEDIUM | Two copyright emails coexist across headers: `jonathan.jewell@open.ac.uk` (canonical) and `j.d.a.jewell@open.ac.uk` (6 files), despite `CHANGELOG.md:30-32` claiming attribution was normalised. | `grep -rl "j.d.a.jewell" --include="*.md" --include="*.adoc" --include="*.a2ml" .` | Add a `.mailmap` and normalise. Do **not** bulk-sweep SPDX headers — estate policy forbids it and it has mis-licensed files before. |
| **L-4** | LOW | `reuse lint` runs in no workflow and no `just` recipe. Compliance is claimed in `REUSE.toml` and gated nowhere. | `grep -rn "reuse" .github/workflows/ Justfile` → no hits | Add to `ci.yml` alongside the other fast gates. |

## Documentation — D

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **D-1** | HIGH | **No single source of truth.** Every fact is restated in 5–6 places and drifts independently. Re-enabling CI in one commit falsified claims in six documents at once, and none of them noticed for four days. | `READINESS.adoc:50`, `TEST-NEEDS.md:134`, `docs/ZERO-MINUTE-CI.adoc:12,137-141`, `docs/STATE-OF-THINGS.adoc:39-40,182-189`, `CHANGELOG.md:58-59` | **The structural fix.** `scripts/check-doc-facts.sh` — compute each fact from source, compare against every assertion site, fail CI on disagreement. Same shape as `check-toolchain-pins.sh`, which works. `ROADMAP.md` item 2. |
| **D-2** | HIGH | The CRG grade disagreed with itself for five weeks: README badge **D**, `READINESS.adoc` and `STATE.a2ml` **C**, and `READINESS.adoc`'s own history table recorded only D. `just crg-badge` would emit C — a recipe nobody ran. | `grep -n CRG README.adoc` vs `just crg-grade` | Partly fixed: the history table now records the D→C promotion and names `READINESS.adoc` as the source of truth. **Still open:** nothing *gates* the badge against it. Fold into D-1's script. |
| **D-3** | MEDIUM | `docs/ZERO-MINUTE-CI.adoc` is the most comprehensively stale document here. Its whole premise — that Actions minutes must be avoided — no longer holds, and four of its statements are false. | `docs/ZERO-MINUTE-CI.adoc:12-14,137-141` | Add a superseded banner in the style `.gitlab-ci.yml:4-15` already uses. Retain rather than delete: the owned-compute mechanism is still correct for self-hosted use. |
| **D-4** | MEDIUM | `docs/ZIGZAG-REGIMEN.adoc:41-53` describes, in the present tense, an audit whose every finding has since been fixed — "the Aspect axis is decorative", "`Maybe String`, always `Nothing`", "0 of 238 populated". All were corrected by ADR-003. | `grep -n "decorative\|Maybe String" docs/ZIGZAG-REGIMEN.adoc` | Move the audit into a dated "what this fixed" section. |
| **D-5** | HIGH | `docs/INTEROP-PANIC-ATTACK.adoc:45-46` states *"CI fails if any cited ladder file classifies Holes/Refuted"*. It does not. `aggregate` returns `Ok` unconditionally and the script that would feed it is invoked by nothing. | `grep -rn "emit-aggregate-inputs" .github/ Justfile` → no hits | Correct the document now; close the chain in `ROADMAP.md` item 3. |
| **D-6** | MEDIUM | `CHANGELOG.md` stops at PR #12. PRs #14–#27 are unrecorded, including the CI reversal, both new suites, the 12 theorems and the secret scanner. | `gh pr list --state merged --limit 20` vs `CHANGELOG.md` | Reconstruct from git history, as the file's own note says was done once before. |
| **D-7** | MEDIUM | `CONTRIBUTING.md:9` instructs contributors to "ensure SPDX headers on all files" — which `REUSE.toml:12-18` and `AGENTS.md:15` explicitly **forbid**. A contributor following CONTRIBUTING would violate estate policy. | `sed -n '9p' CONTRIBUTING.md` vs `sed -n '12,18p' REUSE.toml` | Rewrite: files are declared through `REUSE.toml`, not by editing them. Add `just check-pins`, `just lint`, `just ci`. |
| **D-8** | LOW | `README.adoc` links **none** of `PROOFS.adoc`, `TEST-NEEDS.md`, `AGENTS.md`, `ARCHITECTURE.md`, `AUDIT.adoc`. There is no docs index anywhere in the repository. | `grep -c "PROOFS\|TEST-NEEDS\|AGENTS.md" README.adoc` → 0 | Add an index section to `README.adoc`. |
| **D-9** | LOW | `container/README.adoc:25-26` promises that `{{PLACEHOLDER}}` tokens are replaced by `just container-init` or `just init`. **Neither recipe exists.** | `just --list \| grep -c "container-init\|^init"` → 0 | Either write the recipe or delete the promise. See C-4. |
| **D-10** | LOW | `GOVERNANCE.md` carries two mutually inconsistent dates (`:12` 2026-08-03, `:76` 2026-07-18). | `grep -n "2026-0" GOVERNANCE.md` | Single date. |

## Code — C

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **C-1** | MEDIUM | `tests/TypeSafeTests/ZigzagTests.idr` (116 lines) sat uncommitted in the working tree. It defines its **own** `Aspect` type (Auth/DB/Network/Telemetry) and a second Zigzag model that collides conceptually with the 14-aspect lattice in `Types.idr`. | file present, untracked, at `0bc912c` | **Needs an owner ruling** — reconcile with the existing model, or scope it as a distinct concern under a different name. Deliberately not landed: two incompatible "Zigzag" models in one repo is the split-brain this repo exists to catch. |
| **C-2** | MEDIUM | `container/**` (11 files) and `.devcontainer/**` (3 files) are uninstantiated `{{PLACEHOLDER}}` template boilerplate. `container/manifest.toml:24` is not even valid TOML un-substituted. | `grep -rl "{{" container/ .devcontainer/` | Instantiate or delete. `ROADMAP.md` item 5. |
| **C-3** | HIGH | **The dev container cannot work.** `.devcontainer/devcontainer.json:24` runs `just deps` as its `postCreateCommand`; `scripts/install-idris2.sh:19-21` uses `apt-get`; `.devcontainer/Containerfile:8` is `FROM cgr.dev/chainguard/wolfi-base` — which has `apk`, not `apt-get`. | read the three files | Make the installer detect the package manager, or change the base image. Anyone opening this in a dev container hits it immediately. |
| **C-4** | LOW | `.devcontainer/Containerfile:23` uses `\|\| true` on a `groupadd`/`useradd` line — a gate shape `AGENTIC.a2ml:46-51` explicitly bans. | `grep -n "|| true" .devcontainer/Containerfile` | Replace with an idempotent check. |
| **C-5** | LOW | `alwaysTrueRelation` in `Dyadic.idr` was `public export` and referenced by nothing until PR #27 pressed it into service as a positive fixture. Dead exports mask intent. | `grep -rn alwaysTrueRelation src/ tests/` | Now live. Watch for others. |

## Proof — P

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **P-1** | MEDIUM | The strict subject grading reports **0 Actually-Proven** across `proven`'s 88 modules: 256 outstanding axioms in the OWED ledger, 6 clean modules. Four modules `proven` declares first-class are capped because they carry axioms. | `just ci` → subject report, 2026-08-07 | This is a finding *about `proven`*, correctly reported. Track upstream; it is the honest reading and should not be softened. |
| **P-2** | MEDIUM | The subject report does **not** re-check `proven`'s proofs — it is derived entirely from `proven`'s own self-audit artefacts. Correctly disclosed in its TRUST NOTE, but it means the grade rests on a self-report. | `integrations/proven/` TRUST NOTE | Independent re-checking is a much larger piece of work. Record the limitation wherever the grade is cited. |
| **P-3** | MEDIUM | The subject grading step is `continue-on-error: true`, so it informs and does not gate — while `READINESS.adoc` rests its grade on it. | `.github/workflows/ci.yml:123-127` | Decide whether the CRG evidence step should be allowed to fail the build. Coupled to the re-score. |
| **P-4** | LOW | Only 2 of 35 lattice cells are Actually-Proven. The tier that cannot rot is the smallest. | `./build/exec/proven-tests \| grep -c Actually` | `ROADMAP.md` item 4 — grow it. |

## Test — T

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **T-1** | HIGH | Four categories — property-based, mutation, fuzz, chaos — are **THIN**: fixed vectors wearing category labels that require generators, mutants, adversarial input and fault injection. | [`TEST-NEEDS.md`](TEST-NEEDS.md) Gap E | Tiers downgraded and cells renamed in PR #27 so the run output shows `[Unproven]`. Real implementations are `ROADMAP.md` item 1. |
| **T-2** | MEDIUM | Contract/Invariant and Regression are THIN for a structural reason: no contractile files (`Mustfile`, `Trustfile`, K9, ADJUST) exist to verify, and the `regression-*` cells are tied to no bug, issue or commit. | [`TEST-NEEDS.md`](TEST-NEEDS.md) rows 12–13 | Tie each `regression-*` cell to the defect it guards, or rename it. |
| **T-3** | MEDIUM | `.pre-commit-config.yaml` runs `validate-k9`, and there is nothing for it to validate. A hook that never sees real input is the "gate that cannot fail" shape `AGENTS.md:13` warns about. | `grep -rn "Mustfile\|Trustfile" --include="*.ncl" .` → only placeholder | Remove the hook until there is a contractile artefact, or add one. |
| **T-4** | MEDIUM | `pre-commit run --all-files` executes in no workflow. Six hooks are configured and none is enforced in CI. | `grep -rn "pre-commit" .github/workflows/` → no hits | Add to `ci.yml`. |
| **T-5** | LOW | Two pre-commit hooks are pinned to `rev: main` — a mutable ref, contradicting the repository's own 40-char-SHA discipline (`AGENTS.md:27`). | `grep -n "rev: main" .pre-commit-config.yaml` | Pin to SHAs. |

## CI/CD — I

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **I-1** | HIGH | **Benchmarks gate nothing.** The harness is honest — monotonic clock, index-varied workloads, an XOR checksum defeating dead-code elimination — but there is no baseline, no thresholds, no history and no regression gate. `benchmarks/` holds exactly three files. The numbers are compared against nothing. | `ls benchmarks/` → 3 files | This is the **last unmet CRG C criterion**. `ROADMAP.md` item 2. Note the trap: with no history σ cannot be computed, so the gate must announce its own inertness loudly (exit 2) rather than return success. |
| **I-2** | HIGH | **`scripts/wire-zero-minute-gate.sh` would weaken branch protection if run.** It `PUT`s protection with `required_pull_request_reviews: null` and `enforce_admins: false`, and requires a context (`owned-compute/idris2`) that no longer gates — while *not* requiring `CI (Idris2)`, which does. | `sed -n '53,59p' scripts/wire-zero-minute-gate.sh` | Add a refusal banner, or delete. Its premise (avoid metered minutes) died when the repo went public. |
| **I-3** | HIGH | **Private-repo Actions minutes were exhausted**, and the failure is silent: runs complete in 3–4s with `conclusion: failure`, **zero steps** and no log. Every estate repo running successfully in the same minutes was public. | `gh api .../runs/31176319907/jobs` → `"steps": []`; cross-checked against 4 public repos | **Resolved** by making the repository public 2026-08-07. Recorded because the signature is easy to misread as a code failure, and it applies to every other private repo in the estate. |
| **I-4** | HIGH | A **phantom required context** blocked all merges: `CodeQL` was required by the ruleset but its workflow was `workflow_dispatch:`-only, so it never reported. `mergeStateStatus: BLOCKED` with every check green and `mergeable: MERGEABLE`. | `gh pr view 27 --json mergeStateStatus` before/after | **Resolved** by re-enabling CodeQL on push/PR (free now the repo is public) — not by `--admin`. Making the required check actually run is the correct fix. |
| **I-5** | MEDIUM | `scripts/emit-aggregate-inputs.sh` exits 0 when `panic-attack` is absent — a skip-as-pass shape. It is invoked by nothing, so this is latent rather than active. | `sed -n '55,58p' scripts/emit-aggregate-inputs.sh` | Exit 2 on a missing tool, per the `check-toolchain-pins.sh` convention. |
| **I-6** | MEDIUM | `.gitlab-ci.yml` is dormant — no GitLab project, nothing in it has ever run — but `check-toolchain-pins.sh:60-62` reads it for a pin, so it cannot simply be deleted. Its own header is accurate; four other documents contradict it. | `git remote -v` → GitHub only | Keep, with the header. Fix the four documents (D-1). |
| **I-7** | LOW | `.github/funding.yml` was lowercase. GitHub reads only `.github/FUNDING.yml`, so the sponsor button had never rendered. | GitHub docs; file listing | **Fixed** in this PR. |
| **I-8** | LOW | No `ISSUE_TEMPLATE/`, no `PULL_REQUEST_TEMPLATE.md`, no `SUPPORT.md`, no release automation. `CHANGELOG.md` has a `[0.1.0]` entry and there is **no tag**. | `git tag` → empty | Now that the repo is public these matter. `ROADMAP.md` item 6. |
| **I-9** | LOW | No `CITATION.cff`, `.zenodo.json` or `codemeta.json`, on a research-adjacent repository that cites standards. | file listing | Add `CITATION.cff`. |
| **I-10** | MEDIUM | **Dependabot-actor PR runs are policy-refused on this account.** PR #29's three workflows all hit `startup_failure` in 0s (zero steps, no logs) on the `pull_request` event — including Secret Scanner, which the diff did not touch — while the identical content ran green pushed to main (12:36, 2026-08-10) and on a `workflow_dispatch` minutes later. Dependabot actions-PRs therefore merge unvalidated. | `gh api .../runs` timeline 2026-08-10; run 31388969899 | **Decided:** `gh actions-lock` is the bump mechanism; Dependabot is a notifier only (see `.github/dependabot.yml` header). Close its actions PRs and re-lock. |

## Supply chain & metadata — S

| ID | Sev | Item | Evidence | Next move |
|---|---|---|---|---|
| **S-1** | MEDIUM | **Three incompatible A2ML dialects coexist** and one validator runs across all of them: `.machine_readable/6a2/*` is headerless TOML, `0-AI-MANIFEST.a2ml` is versioned TOML, `container/0.1-AI-MANIFEST.a2ml` is YAML with `@context v2`. | `head -5` each; `.pre-commit-config.yaml:22-26` | Pick one dialect. Estate-wide issue, tracked in the A2ML/IANA work. |
| **S-2** | MEDIUM | `STATE.a2ml:41` and `ECOSYSTEM.a2ml:15` claim the panic-attack integration works. `NEUROSYM.a2ml:69` says it does not, in the same directory. | `grep -rn "panic-attack" .machine_readable/6a2/` | The pessimistic reading is correct (D-5). Correct both overclaims. |
| **S-3** | MEDIUM | `META.a2ml` stops at ADR-005. `GOVERNANCE.md:47-51` requires an ADR for every architectural change; re-enabling CI, adding `proven-spec-suite`, adding the secret scanner and ratifying `TypeSafeTest` as a local extension all lack one. | `grep -c "^\[architecture-decisions" .machine_readable/6a2/META.a2ml` | Write the four missing ADRs. |
| **S-4** | MEDIUM | **Taxonomy drift, unratified.** This repo implements **17** categories; the estate standard defines **16**. `TypeSafeTest` exists in no standard. Only `NEUROSYM.a2ml:44-48` states this; `README.adoc:28` and `tests/README.adoc:14-17` imply the standard defines 17. | `grep -rn "taxonomy-drift" .machine_readable/` | **Needs an owner ruling:** the standard adopts it, or this repo marks it a local extension everywhere. |
| **S-5** | LOW | `ECOSYSTEM.a2ml` has no `last-updated` key at all. | `grep -c last-updated .machine_readable/6a2/ECOSYSTEM.a2ml` → 0 | Add one. |
| **S-6** | LOW | `.github/workflows/main-estate-audit.yml` was found untracked in the working tree — an estate-sweep artefact, not repository work. Not committed. | `git status` at `3dde6a6` | Confirm whether the estate sweep intends to install it. |
| **S-7** | LOW | Two local commits (`da0afbc`, `82b455c`) from an estate-wide sweep were dropped: they re-introduced the 327-line *Squisher Corpus* `CODE_OF_CONDUCT.md` and a 6-ecosystem `dependabot.yml` containing the invalid `nix` value, which #21 had removed with a documented comment. | `git show da0afbc --stat`; both recoverable from reflog | **Root cause is upstream:** the sweep carries a pre-fix payload. Worth checking which other repos it hit. |

---

## Fixed in this pass

Recorded so the register shows movement rather than only accumulation.

| Was | Evidence it is fixed |
|---|---|
| `proven-spec-suite` gated by nothing — 75 tests, 12 theorems | runs in `just ci`; CI log shows 75/75 |
| Reproducibility cell could not fail | injected non-determinism → `Failed`, exit 1 |
| `relationTransitive` vacuously true at (1,2,3) | non-transitive relation declaring transitivity → rejected |
| `relationIsEquivalence` trusted self-declared flags | `declaredFlagsHonest` holds declarations to behaviour |
| `choreographicNoOrphanedChoices` never descended into `Send` | nested orphan fixture → rejected |
| Coverage grid computed and discarded | grid prints on every run |
| 5 cells overclaimed a Kategoria-6 certificate | downgraded to `[Unproven]` in the run output |
| Escape-hatch gate covered 4 of 6 banned patterns, in 2 copies | one script, all 6 verified caught |
| `0-AI-MANIFEST.a2ml` claimed "full test taxonomy implementation" | corrected; the file agents read first |
| Repository private → no CI, phantom-blocked merges | public; CodeQL reporting; `mergeStateStatus: CLEAN` |
