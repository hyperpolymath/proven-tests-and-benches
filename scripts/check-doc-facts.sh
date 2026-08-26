#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# The anti-drift gate: every fact a document asserts is COMPUTED from its
# source of truth and compared against every place it is restated.
#
# WHY THIS EXISTS
# ---------------
# On 2026-08-03 one commit (re-enabling CI on push/PR) falsified statements in
# SIX documents at once, and none of them noticed for four days. The 2026-08-07
# documentation pass corrected ~40 stale statements by hand; without this gate
# the next merged PR starts the drift again. The pattern is proven in this
# repository: check-toolchain-pins.sh does exactly this for the Idris2 version
# across seven artefacts and has been observed failing on injected drift.
#
# TWO MODES (the facts have two sources with different costs)
# -----------------------------------------------------------
#   check-doc-facts.sh source     facts derivable from the source tree alone
#                                 (runs BEFORE the Idris2 bootstrap — cheap)
#   check-doc-facts.sh report <run-report.json>
#                                 facts only a real run produces (suite pass
#                                 counts) — runs AFTER the gate built and ran
#   check-doc-facts.sh            both = source (report checks skipped LOUDLY)
#
# Exit codes, per the check-toolchain-pins.sh convention:
#   0  every checked fact agrees everywhere it is asserted
#   1  at least one document disagrees with a computed fact
#   2  a fact could not be computed or a required file is missing —
#      NO CHECK WAS PERFORMED is not a pass

set -uo pipefail

MODE="${1:-source}"
REPORT="${2:-}"

fail=0
skip=0

say()  { printf '%s\n' "$*"; }
bad()  { printf 'DRIFT: %s\n' "$*" >&2; fail=1; }
dead() { printf 'NO CHECK: %s\n' "$*" >&2; skip=1; }

need() { # need <file> — mark uncheckable if absent
  if [ ! -f "$1" ]; then dead "required file '$1' is missing"; return 1; fi
}

# ---------------------------------------------------------------------------
# Fact 1: library module count. Source of truth: proven-tests.ipkg.
# ---------------------------------------------------------------------------
check_module_count() {
  need proven-tests.ipkg || return
  local n
  n=$(awk '/^modules *=/{flag=1} flag{print}' proven-tests.ipkg \
      | tr ',' '\n' | sed 's/modules *=//' | grep -c '[A-Za-z]')
  if [ -z "$n" ] || [ "$n" -eq 0 ]; then dead "could not count modules in proven-tests.ipkg"; return; fi
  say "computed: library modules = $n (proven-tests.ipkg)"

  # Asserted in:
  grep -q "# ${n} modules: the framework" README.adoc \
    || bad "README.adoc structure block does not say '${n} modules'"
  grep -q "The framework library (${n} modules)" ARCHITECTURE.adoc \
    || bad "ARCHITECTURE.adoc does not say '(${n} modules)'"
  grep -q "framework library (${n} modules)" READINESS.adoc \
    || bad "READINESS.adoc does not say '(${n} modules)'"
  grep -q "library-modules = ${n}" .machine_readable/6a2/STATE.a2ml \
    || bad "STATE.a2ml library-modules != ${n}"
  grep -q "all ${n} modules build" docs/STATE-OF-THINGS.adoc \
    || bad "docs/STATE-OF-THINGS.adoc does not say 'all ${n} modules build'"
}

# ---------------------------------------------------------------------------
# Fact 2: package count. Source of truth: tracked .ipkg files.
# ---------------------------------------------------------------------------
check_package_count() {
  local n words w
  n=$(git ls-files '*.ipkg' | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || { dead "git ls-files found no .ipkg files"; return; }
  say "computed: packages = $n (git ls-files '*.ipkg')"
  words=(zero one two three four five six seven eight nine)
  w=${words[$n]:-$n}
  grep -qi "builds \*\*${w}\*\* Idris2 packages" ARCHITECTURE.adoc \
    || bad "ARCHITECTURE.adoc does not say 'builds **${w}** Idris2 packages'"
}

# ---------------------------------------------------------------------------
# Fact 3: lattice cell count. Source of truth: cellTests in Cells.idr.
# ---------------------------------------------------------------------------
check_cell_count() {
  need src/ProvenTests/Cells.idr || return
  local n
  n=$(awk '/^cellTests/{flag=1} /runAllCells/{flag=0} flag' src/ProvenTests/Cells.idr \
      | grep -cE '\(K (Co)')
  [ "$n" -gt 0 ] || { dead "could not count cellTests coordinates in Cells.idr"; return; }
  say "computed: lattice cells = $n (Cells.idr cellTests)"
  grep -qE "The ${n} lattice cells" ARCHITECTURE.adoc \
    || bad "ARCHITECTURE.adoc does not describe 'The ${n} lattice cells'"
  grep -q "(${n} lattice cells + 1 self-classification)" TEST-NEEDS.adoc \
    || bad "TEST-NEEDS.adoc does not say '(${n} lattice cells + 1 self-classification)'"
}

# ---------------------------------------------------------------------------
# Fact 4: category and aspect counts. Source of truth: Taxonomy.idr lists.
# ---------------------------------------------------------------------------
check_axes() {
  need src/ProvenTests/Taxonomy.idr || return
  local cats asps
  # Strip everything up to the opening bracket and after the closing one, so
  # neither the binding name nor stray text can inflate the entry count.
  cats=$(awk '/^allTestCategories =/{flag=1} flag{print} flag&&/\]/{exit}' \
         src/ProvenTests/Taxonomy.idr | tr -d '\n' \
         | sed 's/.*\[//; s/\].*//' | tr ',' '\n' | grep -cE '[A-Za-z]')
  asps=$(awk '/^allTestAspects =/{flag=1} flag{print} flag&&/\]/{exit}' \
         src/ProvenTests/Taxonomy.idr | tr -d '\n' \
         | sed 's/.*\[//; s/\].*//' | tr ',' '\n' | grep -cE '[A-Za-z]')
  if [ "$cats" -eq 0 ] || [ "$asps" -eq 0 ]; then
    dead "could not count categories/aspects in Taxonomy.idr"; return
  fi
  say "computed: categories = $cats, aspects = $asps (Taxonomy.idr)"
  grep -q "${cats}-category × ${asps}-aspect\|${cats} categories × ${asps} aspects\|${cats}×${asps}\|${cats} × ${asps}" README.adoc \
    || bad "README.adoc does not state the ${cats}×${asps} taxonomy"
  local total=$((cats * asps))
  grep -q "cat-aspect-cells-total = ${total}" .machine_readable/6a2/STATE.a2ml \
    || bad "STATE.a2ml cat-aspect-cells-total != ${total}"
}

# ---------------------------------------------------------------------------
# Fact 5: CRG grade agreement. Source of truth: READINESS.adoc Current Grade.
# (Absorbs the inline badge check that used to live in ci.yml.)
# ---------------------------------------------------------------------------
check_grade() {
  need READINESS.adoc || return
  local want badge state
  want=$(grep "Current Grade:" READINESS.adoc | head -1 \
         | sed 's/.*Current Grade:[^A-Z]*\([A-Z]\).*/\1/')
  [ -n "$want" ] || { dead "no 'Current Grade:' in READINESS.adoc"; return; }
  say "computed: CRG grade = $want (READINESS.adoc)"
  badge=$(grep -oE 'badge/CRG-[A-Z]-' README.adoc | head -1 | sed 's|badge/CRG-\([A-Z]\)-|\1|')
  [ "$want" = "$badge" ] \
    || bad "README badge is CRG-${badge} but READINESS.adoc says CRG-${want} (run: just crg-badge-sync)"
  state=$(grep -oE 'readiness-grade = "[A-Z]"' .machine_readable/6a2/STATE.a2ml | grep -oE '[A-Z]"' | tr -d '"')
  [ "$want" = "$state" ] \
    || bad "STATE.a2ml readiness-grade is ${state} but READINESS.adoc says ${want}"
  # Root READINESS.adoc is GENERATED from READINESS.adoc (just crg-readiness-md)
  # for the estate parser convention; the pair must agree.
  if [ -f READINESS.adoc ]; then
    md=$(grep -oE '\*\*Current Grade:\*\* [A-Z]' READINESS.adoc | tail -1 | grep -oE '[A-Z]$')
    [ "$want" = "$md" ] \
      || bad "READINESS.adoc (generated) says ${md} but READINESS.adoc says ${want} (run: just crg-readiness-md)"
  else
    dead "READINESS.adoc is missing — generate it with: just crg-readiness-md"
  fi
}

# ---------------------------------------------------------------------------
# Fact 6: DEBT register count. Source of truth: the item IDs in the tables.
# (The header claimed 36 items while the tables held 44 — found 2026-08-10.)
# ---------------------------------------------------------------------------
check_debt_count() {
  need DEBT.adoc || return
  local n
  n=$(grep -coE '^\| \*\*[A-Z]+-[0-9]+\*\*' DEBT.adoc)
  [ "$n" -gt 0 ] || { dead "could not count DEBT item IDs"; return; }
  say "computed: DEBT items = $n (ID rows in DEBT.adoc)"
  grep -qE "\b${n} (debt )?items\b|with ${n} items|${n} items across" DEBT.adoc \
    || bad "DEBT.adoc never states its own true item count (${n}); its header/prose disagrees"
}

# ---------------------------------------------------------------------------
# Report-mode facts: suite pass counts. Source of truth: the run report JSON.
# ---------------------------------------------------------------------------
check_report_facts() {
  if [ -z "$REPORT" ] || [ ! -f "$REPORT" ]; then
    dead "report mode requested but no run report given/found"
    return
  fi
  local total passed
  total=$(python3 - "$REPORT" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
rs=d.get("results") or d.get("entries") or []
print(len(rs))
PY
  )
  passed=$(python3 - "$REPORT" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
rs=d.get("results") or d.get("entries") or []
print(sum(1 for r in rs if (r.get("result") or r.get("status") or "").lower().startswith("pass")))
PY
  )
  if [ -z "$total" ] || [ "$total" -eq 0 ]; then
    dead "run report parsed to zero entries — cannot verify suite counts"
    return
  fi
  say "computed: framework suite = ${passed}/${total} (run report)"
  grep -q "framework-suite = \"${passed}/${total} passing\"" .machine_readable/6a2/STATE.a2ml \
    || bad "STATE.a2ml framework-suite != ${passed}/${total}"
  # Coverage counts, from the same report's summary (runReportJSON writes them).
  local covered
  covered=$(python3 - "$REPORT" <<'PY2'
import json,sys
d=json.load(open(sys.argv[1]))
v=(d.get("summary") or {}).get("covered_cells")
print(v if v is not None else "")
PY2
  )
  if [ -n "$covered" ]; then
    say "computed: covered cat-aspect cells = ${covered} (run report)"
    grep -q "cat-aspect-cells-covered = ${covered}" .machine_readable/6a2/STATE.a2ml \
      || bad "STATE.a2ml cat-aspect-cells-covered != ${covered}"
  else
    dead "run report carries no coverage count — cannot verify STATE.a2ml coverage"
  fi
}

# ---------------------------------------------------------------------------

say "== check-doc-facts (${MODE}) =="

# Preflight: every file this gate asserts AGAINST must exist. A missing
# assertion site is NO CHECK (exit 2), never a drift finding — a grep against
# an absent file "not matching" is the crash-reads-as-silence failure mode the
# test doctrine forbids (docs/TEST-DOCTRINE.adoc).
if [ "$MODE" = "source" ]; then
  for f in README.adoc ARCHITECTURE.adoc READINESS.adoc TEST-NEEDS.adoc DEBT.adoc \
           docs/STATE-OF-THINGS.adoc .machine_readable/6a2/STATE.a2ml; do
    need "$f" >/dev/null || true
  done
  if [ "$skip" -ne 0 ]; then
    say "FAIL: assertion-site file(s) missing — NO CHECK WAS PERFORMED."
    exit 2
  fi
fi

case "$MODE" in
  source)
    check_module_count
    check_package_count
    check_cell_count
    check_axes
    check_grade
    check_debt_count
    ;;
  report)
    check_report_facts
    ;;
  *)
    dead "unknown mode '${MODE}' (use: source | report <json>)"
    ;;
esac

if [ "$fail" -ne 0 ]; then
  say "FAIL: documented facts disagree with computed reality. Fix the documents"
  say "      (or the computation if the world changed) — never leave them split."
  exit 1
fi
if [ "$skip" -ne 0 ]; then
  say "FAIL: at least one fact could not be checked. A skip is not a pass."
  exit 2
fi
say "OK: every checked fact agrees everywhere it is asserted."
