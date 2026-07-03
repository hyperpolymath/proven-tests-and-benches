<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
-->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `proven-tests-suite.ipkg`: the nine `tests/TypeSafeTests/` category suites,
  ported to the current Framework API (`ProvisionallyProvenTest` records),
  wired into a buildable package with a CI-gating `Main` (previously stale
  dead code targeting a removed `Test : ProvenStatus -> Type` API).
- `READINESS.adoc`: Component Readiness Grade under the estate CRG v1.0
  convention (current grade: D), with machine-greppable
  `Current Grade:` line consumed by `just crg-grade` / `just crg-badge`.
- CHANGELOG reconstructed from git history (PRs #1–#12).

### Changed
- License headers normalized repo-wide: exactly one SPDX line per file —
  MPL-2.0 (code), CC-BY-SA-4.0 (docs). Removed the fictional
  "Mozilla Post-Quantum License Provisions v1.0" line, stray
  `AGPL-3.0-or-later` identifiers (`Coverage.idr`, `Cells.idr`), and
  triplicated SPDX lines.
- Author attribution normalized to
  `Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>`
  (was split between "Joshua Jewell (JoshuaJewell)" and variants).
- `Justfile` rewritten to match reality: recipes now call
  `proven-tests.ipkg` / `proven-tests-suite.ipkg` / `scripts/ci-build.sh`
  (previously referenced a nonexistent `ipkg.json`, unimplemented
  `--category` flags, and had a duplicate `test` recipe that failed to parse).
- `README.adoc` rewritten: real build instructions, real repository
  structure, honest labeling of the echo-types stand-in, single-license
  statement, links to the self-audit and CRG documents.
- `scripts/ci-build.sh`: support-library path now derived by glob instead of
  hardcoding `idris2-0.7.0`; builds and runs the suite package.

## [0.1.0] - 2026-06-24

### Added
- Self-deriving coverage map: a covered cell requires a real, executed,
  passing test at that typed `ZigzagCoord` (PR #12, #11).
- First populated Zigzag lattice cell: a real end-to-end test (PR #8).
- Cross-repo unification: machine-checked tropical (min-plus) semiring with
  total equality proofs and the `BatonSpec` contract type (PR #6).
- Zero-minute owned-compute CI gate posting GitHub commit statuses, plus
  one-command wiring script (PR #5, #7).
- Dormant push-email notification workflow (PR #10).
- Zigzag regimen: co-phase × actor × category × aspect organising lattice
  (PR #3).

### Changed
- GitHub Actions workflow made manual-only to stop consuming minutes; GitLab
  CI (`idris2` job) is the hosted gate (PR #4).
- Licence normalisation pass toward MPL-2.0 (code) + CC-BY-SA-4.0 (docs)
  (PR #9; completed in [Unreleased]).

### Fixed
- The 4 failing suites (10/10 green) and real Idris2 CI wiring (PR #2).
- Framework compiles end-to-end; provenance made evidence-carrying; honest
  benchmark harness added (PR #1).

## [0.0.1] - 2026-06-08

### Added
- Initial repository structure.
