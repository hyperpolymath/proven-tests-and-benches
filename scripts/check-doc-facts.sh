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
# FOUR MODES (the facts have sources with different costs)
# --------------------------------------------------------
#   check-doc-facts.sh source     facts derivable from the source tree alone
#                                 (runs BEFORE the Idris2 bootstrap — cheap)
#   check-doc-facts.sh report <run-report.json>
#                                 facts only a real run produces (suite pass
#                                 counts) — runs AFTER the gate built and ran
#   check-doc-facts.sh corpus     compiles every corpus unit standalone and
#                                 fires its 0/1/2 triple. NEEDS THE TOOLCHAIN,
#                                 so it cannot live in `source` — an absent
#                                 idris2 is exit 2 here, never 0
#   check-doc-facts.sh corpus-selftest
#                                 runs the gate against synthetic trees that
#                                 MUST trip it. A gate that has not been
#                                 deliberately tripped is not a gate
#   check-doc-facts.sh corpus-count
#                                 REGENERATES corpus/COUNT.a2ml from the walk.
#                                 The ledger is a GENERATED artefact; `source`
#                                 mode fails if the committed copy and a fresh
#                                 walk disagree
#   check-doc-facts.sh            both = source (report checks skipped LOUDLY)
#
# Exit codes, per the check-toolchain-pins.sh convention:
#   0  every checked fact agrees everywhere it is asserted
#   1  at least one document disagrees with a computed fact
#   2  a fact could not be computed or a required file is missing —
#      NO CHECK WAS PERFORMED is not a pass

set -uo pipefail

# ⚠ The generated ledger is compared BYTE-FOR-BYTE against its committed copy,
# and `find … | sort` orders its [units] block. `sort` collates by locale, so
# the same corpus can generate two different byte streams on two machines —
# green here, stale in CI, for a reason no diff explains. One unit cannot
# expose this; the first unit whose id differs from another only by a hyphen
# or an underscore will. Pin it once, at the top, for every subshell too.
export LC_ALL=C

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
  grep -q "library-modules = ${n}" .machine_readable/descriptiles/STATE.a2ml \
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
  grep -qi "builds \*${w}\* Idris2 packages" ARCHITECTURE.adoc \
    || bad "ARCHITECTURE.adoc does not say 'builds *${w}* Idris2 packages'"
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
  tr '\n' ' ' < TEST-NEEDS.adoc | grep -q "(${n} lattice cells + 1 self-classification)" \
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
  grep -q "cat-aspect-cells-total = ${total}" .machine_readable/descriptiles/STATE.a2ml \
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
  state=$(grep -oE 'readiness-grade = "[A-Z]"' .machine_readable/descriptiles/STATE.a2ml | grep -oE '[A-Z]"' | tr -d '"')
  [ "$want" = "$state" ] \
    || bad "STATE.a2ml readiness-grade is ${state} but READINESS.adoc says ${want}"
  # Root READINESS.md is GENERATED from READINESS.adoc (just crg-readiness-md)
  # for the estate CRG parser convention; the pair must agree.
  # NOTE: the .md here is DELIBERATE — do not repoint it at .adoc. Comparing
  # the generated file against itself makes this check a tautology that can
  # never fail.
  if [ -f READINESS.md ]; then
    md=$(grep -oE '\*\*Current Grade:\*\* [A-Z]' READINESS.md | tail -1 | grep -oE '[A-Z]$')
    [ "$want" = "$md" ] \
      || bad "READINESS.md (generated) says ${md} but READINESS.adoc says ${want} (run: just crg-readiness-md)"
  else
    dead "READINESS.md is missing — generate it with: just crg-readiness-md"
  fi
}

# ---------------------------------------------------------------------------
# Fact 6: DEBT register count. Source of truth: the item IDs in the tables.
# (The header claimed 36 items while the tables held 44 — found 2026-08-10.)
# ---------------------------------------------------------------------------
check_debt_count() {
  need DEBT.adoc || return
  local n
  n=$(grep -cE '^\|\*[A-Z]+-[0-9]+\*' DEBT.adoc)
  [ "$n" -gt 0 ] || { dead "could not count DEBT item IDs"; return; }
  say "computed: DEBT items = $n (ID rows in DEBT.adoc)"
  grep -qE "${n} (debt )?items|with ${n} items|${n} items across" DEBT.adoc \
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
  grep -q "framework-suite = \"${passed}/${total} passing\"" .machine_readable/descriptiles/STATE.a2ml \
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
    grep -q "cat-aspect-cells-covered = ${covered}" .machine_readable/descriptiles/STATE.a2ml \
      || bad "STATE.a2ml cat-aspect-cells-covered != ${covered}"
  else
    dead "run report carries no coverage count — cannot verify STATE.a2ml coverage"
  fi
}

# ---------------------------------------------------------------------------

say "== check-doc-facts (${MODE}) =="

# ===========================================================================
# CORPUS MODES (added 2026-09-15, WS1 commit B)
#
# `corpus` is the executable gate R-29 demanded: it compiles every corpus unit
# standalone and fires its 0/1/2 triple. It owns the compile predicate outright
# — the corpus-check workflow is a thin caller, so the predicate below is the
# ONLY copy and there is exactly one place to defend.
#
# ⚠ THE COMPILE PREDICATE IS A THREE-WAY CONJUNCTION AND MUST STAY ONE.
# Measured against Idris 2 v0.7.0 on 2026-09-14, standalone `idris2 Test.idr -o`:
#
#   mutation      rc   ^Error: lines   binary emitted
#   clean          0        0              yes
#   bad import     0 ⚠      2              no
#   type error     1        1              yes ⚠
#
# `$?` alone passes a unit that failed to compile (bad import); binary presence
# alone passes a unit with a type error. The natural "simplification" to
# `idris2 … -o x && ./x fixture` therefore silently re-admits the bad-import
# row, accepting a unit that imports ptb's library into the gate whose entire
# purpose is to prove it cannot. R-43's isolation is real rather than declared
# only because more than rc is read.
#
# ⚠ BE PRECISE ABOUT THE THIRD SIGNAL, because the tempting summary is false.
# Measured 2026-09-15: `[ "$CC_ERRS" -eq 0 ]` ALONE discriminates every row of
# the table above. Error-line count is not redundant with the other two — it is
# the strongest of the three on this matrix. It is nonetheless not sufficient,
# and its residue is named rather than hand-waved: it reads "compiled" for any
# failure that prints no ^Error: line at all — a crash, an OOM kill, a timeout,
# a signal, or a future Idris2 that changes its diagnostic prefix, which is not
# a documented interface. rc and binary presence cover exactly that residue.
#
# So this is defence-in-depth over a declared residue, not three independently
# necessary signals, and the selftest proves it that way: badimport kills the
# rc-only predicate, typeerr kills the binary-only predicate, and silentfail
# kills the error-count-only predicate. Every single-signal collapse of this
# conjunction reddens at least one tree. Do not collapse it.
# ===========================================================================

CORPUS_ROOT="${CORPUS_ROOT:-corpus}"
IDRIS2="${IDRIS2:-idris2}"

# The unit contract, ultraplan §★.1. SIX manifests — diagnosticity, regime,
# error-model, stability, depends, manifest — plus Test.idr, README.adoc and
# three fixture directories.
#
# ⚠ THIS LIST IS A LITERAL ON PURPOSE. Deriving the required spine from an
# existing unit would make the gate structurally incapable of failing that
# unit: delete a manifest from the only unit in the corpus and a derived list
# would shrink to match, reporting OK. That is the estate's most-recorded trap
# (a guard that asks a different question than its consumer) aimed squarely at
# the guard's own subject. The literal can fail unit #1, which is the point.
CORPUS_SPINE_FILES=(Test.idr README.adoc manifest.a2ml regime.a2ml \
                    error-model.a2ml stability.a2ml depends.a2ml \
                    diagnosticity.a2ml)
CORPUS_SPINE_DIRS=(fixture-silent fixture-firing calibration)

# ---------------------------------------------------------------------------
# Discovery. By MARKER (manifest.a2ml), never by a fixed-depth glob.
#
# ⚠ A glob of the shape "$CORPUS_ROOT"/*/*/*/ matches only three-level units
# and walks silently past anything else. A unit filed at the wrong depth would
# then be uncounted rather than reported — hand-counting by omission, which is
# exactly what R-29 outlawed. Marker discovery finds every unit at any depth;
# the depth CONTRACT is then asserted separately below, so a misfiled unit is a
# loud finding instead of an invisible one.
# ---------------------------------------------------------------------------
#
# ⚠ ONE WALK, TWO QUESTIONS, TWO DIFFERENT VERDICTS ON EMPTINESS.
# `corpus` mode asks "did every unit compile and fire?" — with no units there
# is nothing to compile, NO CHECK was performed, and that is exit 2. The
# LEDGER asks "how many units are deployed?" — with no units the honest answer
# is deployed = 0, which is a measurement, not a void. Same find(1), opposite
# meanings, so the caller declares which question it is asking.
corpus_discover() { # corpus_discover [allow-empty] — populates CORPUS_UNITS[]
  local empty_ok="${1:-}"
  CORPUS_UNITS=()
  if [ ! -d "$CORPUS_ROOT" ]; then
    [ "$empty_ok" = allow-empty ] && return 0
    dead "corpus root '$CORPUS_ROOT' does not exist"
    return 1
  fi
  mapfile -t CORPUS_UNITS < <(find "$CORPUS_ROOT" -type f -name manifest.a2ml -printf '%h\n' | sort)
  if [ "${#CORPUS_UNITS[@]}" -eq 0 ]; then
    # Zero units is NO CHECK, never "0 units, all fine". An empty corpus that
    # reported OK would be the six-number headline's fake green at the root.
    [ "$empty_ok" = allow-empty ] && return 0
    dead "no corpus units found under '$CORPUS_ROOT' (no manifest.a2ml anywhere)"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Spine. Every contract member present, every fixture directory NON-EMPTY.
#
# ⚠ An empty fixture directory is a fake green, not a harmless gap: the triple
# loop below iterates a glob, and over an empty directory it runs zero times
# and reports success having checked nothing. Requiring >=1 regular file is
# verification rule 4 (both arms of a differential gate must be reachable)
# enforced structurally rather than trusted.
# ---------------------------------------------------------------------------
corpus_check_spine() { # corpus_check_spine <unit-dir> -> 0 if complete
  local u="$1" ok=0 f d n rel depth
  rel="${u#"$CORPUS_ROOT"/}"
  depth=$(awk -F/ '{print NF}' <<<"$rel")
  if [ "$depth" -ne 3 ]; then
    # Drift, not VOID: the unit is readable, it is simply filed against a
    # contract it does not meet. corpus/<battery>/<category>/<id>/.
    bad "$u is at depth ${depth} under $CORPUS_ROOT; the unit contract is corpus/<battery>/<category>/<id>/ (depth 3)"
  fi
  for f in "${CORPUS_SPINE_FILES[@]}"; do
    if [ ! -f "$u/$f" ]; then dead "$u: incomplete unit contract — '$f' is missing"; ok=1; fi
  done
  for d in "${CORPUS_SPINE_DIRS[@]}"; do
    if [ ! -d "$u/$d" ]; then
      dead "$u: incomplete unit contract — '$d/' is missing"; ok=1; continue
    fi
    n=0
    for f in "$u/$d"/*; do [ -f "$f" ] && n=$((n + 1)); done
    if [ "$n" -eq 0 ]; then
      dead "$u: '$d/' holds no payload — an empty fixture directory checks nothing"; ok=1
    fi
  done
  return "$ok"
}

# ---------------------------------------------------------------------------
# The three-signal compile. Sets CC_RC / CC_ERRS / CC_BIN / CC_OUT in the
# CURRENT shell; returns 0 only if all three signals agree the unit compiled.
#
# ⚠ Never call this inside $(...). The whole file runs `set -uo pipefail` with
# no -e, and bad()/dead() mutate fail/skip by assignment — inside a subshell
# those assignments are discarded and the tail prints OK. Same reason the
# fixture loops above use current-shell globs and never `find | while`.
# ---------------------------------------------------------------------------
corpus_compile() { # corpus_compile <unit-dir> <binary-name>
  local u="$1" name="$2" out
  # ⚠ MANDATORY. A stale build/exec/<name> from a previous clean run makes the
  # bad-import row read as rc=0 + binary PRESENT, collapsing the three-signal
  # predicate to a single lying signal. Unit #1 carries a gitignored build/ on
  # disk right now, so this is a live hazard, not a theoretical one.
  rm -rf "$u/build"
  out=$(cd "$u" && "$IDRIS2" Test.idr -o "$name" 2>&1)
  CC_RC=$?                       # no pipe: $? is the compile, not a filter
  CC_OUT="$out"
  CC_ERRS=$(printf '%s\n' "$out" | grep -c '^Error:')
  if [ -x "$u/build/exec/$name" ]; then CC_BIN=1; else CC_BIN=0; fi
  [ "$CC_RC" -eq 0 ] && [ "$CC_ERRS" -eq 0 ] && [ "$CC_BIN" -eq 1 ]
}

# ---------------------------------------------------------------------------
# The triple: silent -> 0, firing -> 1, calibration -> 2.
# ---------------------------------------------------------------------------
corpus_fire() { # corpus_fire <unit-dir> <binary-name> <fixture-dir> <expected-rc>
  local u="$1" name="$2" d="$3" want="$4" f rc rel
  for f in "$u/$d"/*; do
    [ -f "$f" ] || continue
    rel="${f#"$u"/}"
    (cd "$u" && "./build/exec/$name" "$rel" >/dev/null 2>&1)
    rc=$?
    [ "$rc" -eq "$want" ] || \
      bad "$u: $d/$(basename "$f") exited ${rc}, the unit contract requires ${want}"
  done
}

# ---------------------------------------------------------------------------
# Mode `corpus`.
# ---------------------------------------------------------------------------
check_corpus() {
  # A gate that cannot run its subject reports NO CHECK. Reporting 0 here is
  # specimen #5 verbatim ("missing tools must be outcome 2, not green") — the
  # gate that polices that defect may not exhibit it.
  if ! command -v "$IDRIS2" >/dev/null 2>&1; then
    dead "toolchain '$IDRIS2' is not on PATH — no unit can be compiled"
    return
  fi
  corpus_discover || return
  say "computed: corpus units = ${#CORPUS_UNITS[@]} (marker: manifest.a2ml under $CORPUS_ROOT)"

  local u name
  for u in "${CORPUS_UNITS[@]}"; do
    name=$(basename "$u")
    if ! corpus_check_spine "$u"; then
      # An incomplete unit is VOID, not merely unbuilt. Compiling it anyway
      # would produce a verdict about a unit that has no contract to be judged
      # against, and a green downstream of a VOID is reclassified VOID.
      say "VOID: $u — incomplete unit contract, not compiled"
      continue
    fi
    # The declared invocation and the executed one must not drift; the binary
    # name is manifest-declared in [subject_shape].build.
    grep -q -- "-o $name" "$u/manifest.a2ml" \
      || bad "$u: manifest [subject_shape].build does not declare '-o $name'"

    if corpus_compile "$u" "$name"; then
      say "compiled: $u (rc=0, 0 errors, binary present)"
      corpus_fire "$u" "$name" fixture-silent 0
      corpus_fire "$u" "$name" fixture-firing 1
      corpus_fire "$u" "$name" calibration    2
    else
      bad "$u does not compile standalone: rc=${CC_RC}, ^Error: lines=${CC_ERRS}, binary=$([ "$CC_BIN" -eq 1 ] && echo present || echo absent)"
      printf '%s\n' "$CC_OUT" | sed 's/^/    | /' >&2
    fi
  done
}

# ---------------------------------------------------------------------------
# Mode `corpus-selftest` — the gate run against inputs that MUST trip it.
#
# A gate that has not been deliberately tripped is not a gate. Fifteen synthetic
# trees, each isolating EXACTLY ONE defect and asserting both the exit code and
# a pinned line of output.
#
# ⚠ ONE DEFECT PER TREE IS LOAD-BEARING. The tail tests `fail` (exit 1) BEFORE
# `skip` (exit 2), so bad() beats dead(): a tree with both a broken spine and a
# broken import would exit 1 and the spine VOID would be invisible. Each tree
# below therefore starts from a COMPLETE copy of a real unit and mutates one
# thing.
#
# ⚠ Pin error TEXT, never a line number. The plan recorded the isolation
# failure at Test:28:1 and the measured location is Test:27:1 — a selftest
# pinned to the numeral would have failed for a reason unrelated to the defect.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# THE LEDGER. corpus/COUNT.a2ml is the public six-number claim, and R-29 rules
# it is GENERATED, never hand-written. Everything below computes it from the
# per-unit manifests, so the number and the thing it counts cannot drift apart.
#
# ⚠ Every field is derivable from SOURCE alone — no toolchain, no run. That is
# deliberate: `check_corpus_count` lives in `source` mode, which runs before
# the Idris2 bootstrap, so a field that needed a compile could not be checked
# there. A run-dependent fact that cannot be sourced from a unit's own
# stability.a2ml is DROPPED from the ledger rather than faked into it.
#
# ⚠ The output must be byte-stable across runs: no generation timestamp, a
# sorted walk, and a fixed field order. A ledger that differs from itself run
# to run makes `check_corpus_count` fire on noise and trains readers to ignore
# it, which is worse than having no ledger at all.
# ---------------------------------------------------------------------------
a2ml_get() { # a2ml_get <file> <section> <key> — prints the value; empty if absent
  [ -f "$1" ] || return 1
  awk -v want="$2" -v key="$3" '
    /^[[:space:]]*\[/ { s = $0; sub(/^[[:space:]]*\[/, "", s); sub(/\].*$/, "", s); sec = s; next }
    sec == want && $0 ~ ("^[[:space:]]*" key "[[:space:]]*=") {
      v = $0
      sub(/^[^=]*=[[:space:]]*/, "", v)
      sub(/^"/, "", v); sub(/"[[:space:]]*$/, "", v)
      print v; exit
    }
  ' "$1"
}

# The diagnosticity contract: a unit counts as diagnosticity-complete only if
# it declares all five sections. "Has the file" is not the same question as
# "declares what the file is for", and the ledger asks the second one.
corpus_diagnosticity_complete() { # <unit-dir>
  local f="$1/diagnosticity.a2ml" sec
  [ -f "$f" ] || return 1
  for sec in detects sensitivity confusables distinguishing_evidence does_not_distinguish; do
    grep -qE "^[[:space:]]*\[${sec}\]" "$f" || return 1
  done
  return 0
}

gen_corpus_count() { # gen_corpus_count <outfile> — writes the ledger computed from the walk
  local out="$1" u rel tier runs lf repro repl
  local deployed=0 fired=0 diag=0 exact=0 stat=0 repeated=0 reproduced=0 replicated=0
  local newest="" newest_unit="" n=0
  local -a units_out=()

  corpus_discover allow-empty || return 1

  for u in "${CORPUS_UNITS[@]}"; do
    rel="${u#"$CORPUS_ROOT"/}"
    deployed=$((deployed + 1))
    tier=$(a2ml_get "$u/error-model.a2ml" tier value)
    runs=$(a2ml_get "$u/stability.a2ml" repeat runs)
    lf=$(a2ml_get "$u/stability.a2ml" firing_history last_fired)
    repro=$(a2ml_get "$u/stability.a2ml" reproduce performed)
    repl=$(a2ml_get "$u/stability.a2ml" replicate performed)

    # "fired WITH DATE" is the point of the column: an undated firing claim is
    # not evidence, so a bare "yes" must not count here.
    [[ "$lf" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] && fired=$((fired + 1))
    corpus_diagnosticity_complete "$u" && diag=$((diag + 1))
    [ "$tier" = "proven-exact" ] && exact=$((exact + 1))
    # The statistical column requires a DECLARED operating point, not merely a
    # statistical tier — a statistical claim with no (alpha, beta) is exactly
    # the unconditioned number the doctrine forbids.
    if [ "${tier#statistical}" != "$tier" ] \
       && [ -n "$(a2ml_get "$u/error-model.a2ml" alpha value)" ] \
       && [ -n "$(a2ml_get "$u/error-model.a2ml" beta value)" ]; then
      stat=$((stat + 1))
    fi
    [[ "$runs" =~ ^[0-9]+$ ]] && [ "$runs" -ge 2 ] && repeated=$((repeated + 1))
    [ "$repro" = "yes" ] && reproduced=$((reproduced + 1))
    [ "$repl" = "yes" ] && replicated=$((replicated + 1))

    if [ -n "$lf" ] && [[ "$lf" > "$newest" ]]; then newest="$lf"; newest_unit="$rel"; fi
    n=$((n + 1))
    units_out+=("u${n} = \"${rel} tier=${tier:-none} runs=${runs:-0} last_fired=${lf:-none}\"")
  done

  {
    printf '%s\n' '# SPDX-License-Identifier: MPL-2.0'
    printf '%s\n' '# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>'
    printf '%s\n' '#'
    printf '%s\n' '# GENERATED — DO NOT HAND-EDIT. Regenerate with: just corpus-count'
    printf '%s\n' '#'
    printf '%s\n' '# THE COUNT LEDGER — the public claim. Six numbers, never one. A number is'
    printf '%s\n' '# quotable only if every unit in it is individually executable, individually'
    printf '%s\n' '# red-able, carries its canonical wrongness, declares its confusables, states'
    printf '%s\n' '# an error model, and has been run more than once. Any shortfall prints as a'
    printf '%s\n' '# DEFICIT, never buried.'
    printf '%s\n' '#'
    printf '%s\n' '# Every field is computed from the per-unit manifests under corpus/ by'
    printf '%s\n' '# scripts/check-doc-facts.sh. `check-doc-facts.sh source` fails if this file'
    printf '%s\n' '# and a fresh walk disagree, so a hand-edit here is drift, not an update.'
    printf '\n'
    printf '[count]\n'
    printf 'deployed = "%s"\n' "$deployed"
    printf 'fired_with_date = "%s"\n' "$fired"
    printf 'diagnosticity_complete = "%s"\n' "$diag"
    printf 'proven_exact = "%s"\n' "$exact"
    printf 'statistical_with_declared_operating_point = "%s"\n' "$stat"
    printf 'repeat_tested = "%s"\n' "$repeated"
    printf '\n'
    printf '[detail]\n'
    printf 'last_fired = "%s"\n' "${newest:-none} (${newest_unit:-no unit})"
    printf 'authority = "each unit stability.a2ml [firing_history].last_fired; this line is DERIVED"\n'
    printf '\n'
    printf '[deficits]\n'
    # ⚠ DERIVED, not asserted. The predecessor ledger carried a hand-written
    # ci_gate deficit, and a hand-written deficit is retired by whoever edits
    # the file next — which is how a deficit gets dropped before it is
    # discharged. This one clears itself only when a workflow really invokes
    # the unit-running mode, and comes back if that invocation is ever deleted.
    # `corpus-count` and `corpus-selftest` deliberately do NOT satisfy it:
    # neither compiles a unit, so neither discharges this deficit.
    # ⚠ BOTH SPELLINGS, and that is the point. A predicate accepting only the
    # direct invocation would leave the deficit standing while a real CI gate
    # existed, because `just corpus-check` is the natural thing to write in a
    # workflow — the ledger lying in the OTHER direction, with no tree to say
    # so. Trees 16 and 17 pin one spelling each.
    if ! grep -rqE '(check-doc-facts\.sh[[:space:]]+corpus|just[[:space:]]+corpus-check)[[:space:]]*$' .github/workflows 2>/dev/null; then
      printf 'ci_gate = "no workflow runs the corpus mode — units are compiled and fired locally only (DEBT S-9)"\n'
    fi
    printf 'reproduce_tested = "%s of %s — second-machine runs owed (DEBT S-9)"\n' "$reproduced" "$deployed"
    printf 'replicate_tested = "%s of %s — different-setup runs owed (DEBT S-9)"\n' "$replicated" "$deployed"
    printf '\n'
    printf '%s\n' '# Each zero below names the CHECK that enforces it. A zero asserted by'
    printf '%s\n' '# nobody is a wish; a zero enforced by a named gate is a measurement. This'
    printf '%s\n' '# section was [zero_by_assertion] until WS1 commit C gave every line a gate.'
    printf '[zero_by_gate]\n'
    printf 'cannot_fail_by_design = "0 — enforced by corpus_fire <unit> fixture-firing 1 (check-doc-facts.sh corpus): a unit whose firing fixture exits 0 is reported, never counted"\n'
    printf 'undeclared_error_model = "0 — enforced by corpus_check_spine (error-model.a2ml is a contract member) and by check_unit_ledger (a proven-exact tier must name lemmas that exist in Test.idr)"\n'
    printf 'void_counted_as_pass = "0 — enforced by corpus_fire <unit> calibration 2 (check-doc-facts.sh corpus): a calibration payload exiting 0 is reported, never counted"\n'
    printf '\n'
    printf '[units]\n'
    local line
    for line in "${units_out[@]}"; do printf '%s\n' "$line"; done
  } > "$out"
  return 0
}

check_corpus_count() {
  local committed="$CORPUS_ROOT/COUNT.a2ml" gen
  need "$committed" || return
  gen=$(mktemp) || { dead "could not create a temporary file to regenerate the ledger"; return; }
  # ⚠ Called in the CURRENT shell, never as $(gen_corpus_count) — it can call
  # dead(), and a subshell would swallow the flag and print OK.
  if ! gen_corpus_count "$gen"; then rm -f "$gen"; return; fi
  if diff -q "$committed" "$gen" >/dev/null 2>&1; then
    say "computed: $committed agrees with a fresh walk (${#CORPUS_UNITS[@]} unit(s))"
  else
    bad "$committed is stale — regenerate with: just corpus-count"
    diff -u "$committed" "$gen" | sed 's/^/    | /' >&2
  fi
  rm -f "$gen"
}

# ---------------------------------------------------------------------------
# The per-unit coupling the ledger cannot see. COUNT.a2ml is derived from
# stability.a2ml, so regenerating it can never expose a manifest.a2ml that
# disagrees with stability.a2ml — the derivation simply ignores the manifest.
# Commit A recorded that coupling as discipline and promised commit C would
# make it mechanical; this is where that promise is kept.
# ---------------------------------------------------------------------------
check_unit_ledger() {
  corpus_discover allow-empty || return
  local u rel mdate sdate tier lemma
  for u in "${CORPUS_UNITS[@]}"; do
    rel="${u#"$CORPUS_ROOT"/}"
    mdate=$(a2ml_get "$u/manifest.a2ml" adversarial last_fired)
    sdate=$(a2ml_get "$u/stability.a2ml" firing_history last_fired)
    if [ -z "$sdate" ]; then
      dead "$rel: stability.a2ml declares no [firing_history].last_fired — the authority for the firing date is absent"
    elif [ -n "$mdate" ] && [ "$mdate" != "${sdate:0:10}" ]; then
      bad "$rel: manifest [adversarial].last_fired = '$mdate' disagrees with stability.a2ml [firing_history].last_fired = '$sdate' (stability.a2ml is the AUTHORITY)"
    fi

    tier=$(a2ml_get "$u/error-model.a2ml" tier value)
    if [ "$tier" = "proven-exact" ]; then
      # A proven-exact tier is a claim that named total lemmas discharge alpha
      # and beta. A warrant naming a lemma that is not in Test.idr is DRIFT
      # (exit 1), not a deficit: the claim is not weak, it is unfounded.
      # ⚠ Process substitution, NOT a pipe — bad() must mutate the current shell.
      while read -r lemma; do
        [ -n "$lemma" ] || continue
        if ! grep -qE "^${lemma}[[:space:]]*:" "$u/Test.idr"; then
          bad "$rel: error-model.a2ml claims tier proven-exact warranted by lemma '$lemma', but Test.idr declares no such lemma"
        fi
      done < <(grep -oE '[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(Test\.idr\)' "$u/error-model.a2ml" \
               | sed 's/[[:space:]]*(Test\.idr)$//' | sort -u)
    fi
  done
}

corpus_selftest_case() { # <name> <tree> <mode> <want-rc> <want-substring> [env-assignment]
  local case_name="$1" tree="$2" mode="$3" want="$4" pin="$5" envset="${6:-}"
  local out rc
  if [ -n "$envset" ]; then
    out=$(cd "$tree" && env "$envset" CORPUS_ROOT=corpus bash "$SELFTEST_SCRIPT" "$mode" 2>&1)
  else
    out=$(cd "$tree" && CORPUS_ROOT=corpus bash "$SELFTEST_SCRIPT" "$mode" 2>&1)
  fi
  rc=$?
  if [ "$rc" -ne "$want" ]; then
    bad "selftest '$case_name' (${mode}): expected exit ${want}, got ${rc}"
    printf '%s\n' "$out" | sed 's/^/    | /' >&2
    return
  fi
  if ! printf '%s\n' "$out" | grep -qF -- "$pin"; then
    bad "selftest '$case_name' (${mode}): exit ${rc} was right but the reason was not — expected output containing: ${pin}"
    printf '%s\n' "$out" | sed 's/^/    | /' >&2
    return
  fi
  # ATTRIBUTION. The right exit code is not yet the right reason, even with the
  # right text alongside it. `fail` is tested before `skip`, so a tree that is
  # ALSO void exits 1 and looks like a clean red — which is how the broken
  # full-tree copy (a directory that was not a git repository) let three ledger
  # trees pass partly on a harness defect rather than purely on their own.
  # A 0/1 case must therefore emit NO "NO CHECK" line, and a 2 case must emit
  # one: exit 2 with nothing uncheckable would mean the VOID came from nowhere.
  local voids
  voids=$(printf '%s\n' "$out" | grep -c '^NO CHECK: ')
  if [ "$want" != 2 ] && [ "$voids" -ne 0 ]; then
    bad "selftest '$case_name' (${mode}): exit ${rc} for the right reason but the tree was ALSO void — ${voids} NO CHECK line(s); the red is not attributable to the defect under test"
    printf '%s\n' "$out" | grep '^NO CHECK: ' | sed 's/^/    | /' >&2
    return
  fi
  if [ "$want" = 2 ] && [ "$voids" -eq 0 ]; then
    bad "selftest '$case_name' (${mode}): exit 2 with no NO CHECK line — a VOID with no stated cause is indistinguishable from a crash"
    printf '%s\n' "$out" | sed 's/^/    | /' >&2
    return
  fi
  say "selftest OK: $case_name (${mode}) -> exit ${rc}, pinned reason present"
}

check_corpus_selftest() {
  if ! command -v "$IDRIS2" >/dev/null 2>&1; then
    dead "toolchain '$IDRIS2' is not on PATH — the selftest cannot compile anything"
    return
  fi
  corpus_discover || return
  local src="${CORPUS_UNITS[0]}" root
  SELFTEST_SCRIPT=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  local repo_root; repo_root=$(cd "$(dirname "$SELFTEST_SCRIPT")/.." && pwd)
  root=$(mktemp -d) || { dead "could not create a temporary tree for the selftest"; return; }
  # shellcheck disable=SC2064
  trap "rm -rf '$root'" RETURN

  local rel; rel="${src#"$CORPUS_ROOT"/}"
  mk() { # mk <case> -> echoes the tree root, with a pristine unit copy inside
    local t="$root/$1"
    mkdir -p "$t/corpus/$(dirname "$rel")"
    cp -r "$src" "$t/corpus/$rel"
    rm -rf "$t/corpus/$rel/build"   # never copy a stale binary into a fixture
    printf '%s\n' "$t"
  }

  # ⚠ The ledger trees below run `source`, not `corpus`, and `source` reads the
  # whole document spine (ipkg, README, STATE, DEBT, READINESS). A unit-only
  # tree would make every other source check report NO CHECK, and since fail
  # (1) is tested before skip (2) the tree would still exit 1 — for the wrong
  # reason, and the positive control could never reach 0. So these trees are
  # full tracked-file copies of the WORKING tree (not HEAD: the gate under test
  # is usually uncommitted when the selftest runs).
  # Sets SELFTEST_TREE rather than echoing, because it can call dead() and a
  # command substitution would swallow the flag.
  SELFTEST_TREE=""
  mkfull() { # mkfull <case> -> sets SELFTEST_TREE
    local t="$root/$1" rc
    SELFTEST_TREE=""
    mkdir -p "$t" || { dead "could not create selftest tree '$1'"; return 1; }
    # ⚠ `git ls-files` lists the INDEX, so a brand-new file that has not been
    # `git add`ed is invisible to every full-tree case even though it is sitting
    # in the working tree the committed ledger was generated against. That makes
    # the positive control `cleanfull` go red with a perfectly correct predicate:
    # the copy lacks the file, the fresh walk re-derives a deficit the real tree
    # no longer has, and the committed ledger reads as stale. STAGE FIRST, then
    # run the selftest. Do NOT "fix" this by copying untracked files as well —
    # the trees would then inherit build output, editor droppings and any other
    # session's scratch, and the ledger cases would stop being reproducible.
    ( cd "$repo_root" && git ls-files -z | xargs -0 cp --parents -t "$t" ) ; rc=$?
    if [ "$rc" -ne 0 ]; then
      dead "could not build a full-tree selftest copy (git ls-files/cp failed, rc=$rc) — the ledger trees cannot run"
      return 1
    fi
    # ⚠ check_package_count counts packages with `git ls-files '*.ipkg'`, so a
    # plain directory copy reports zero packages and the tree goes VOID. The
    # positive control below is what exposed that; the red trees had been
    # exiting 1 partly on a broken tree rather than purely on their own defect.
    # An index is enough — no commit, no history, no remote.
    ( cd "$t" && git -c init.defaultBranch=main init -q && git add -A ) >/dev/null 2>&1 ; rc=$?
    if [ "$rc" -ne 0 ]; then
      dead "could not index the full-tree selftest copy (git init/add failed, rc=$rc) — the ledger trees cannot run"
      return 1
    fi
    SELFTEST_TREE="$t"
    return 0
  }

  local t

  # 1. POSITIVE CONTROL. Without this the six red trees below prove only that
  #    the gate can say no, not that it can ever say yes — a gate stuck at
  #    "fail" would pass every negative case.
  t=$(mk clean)
  corpus_selftest_case clean "$t" corpus 0 "OK: every checked fact agrees"

  # 2. Bad import: rc=0 on a FAILED compile. The row that breaks `&&`.
  t=$(mk badimport)
  sed -i '0,/^module Test$/s//module Test\nimport ProvenTests.Types/' "$t/corpus/$rel/Test.idr"
  corpus_selftest_case badimport "$t" corpus 1 "does not compile standalone"

  # 3. Type error: rc=1 but a binary IS emitted. The row that breaks a
  #    binary-presence test.
  t=$(mk typeerr)
  printf '\nselftestCanary : Nat\nselftestCanary = "not a Nat"\n' >> "$t/corpus/$rel/Test.idr"
  corpus_selftest_case typeerr "$t" corpus 1 "does not compile standalone"

  # 4. Incomplete spine -> VOID, never uncounted.
  t=$(mk nospine)
  rm -f "$t/corpus/$rel/depends.a2ml"
  corpus_selftest_case nospine "$t" corpus 2 "incomplete unit contract — 'depends.a2ml' is missing"

  # 5. Empty fixture directory -> VOID. The loop would otherwise check nothing
  #    and report success.
  t=$(mk emptyfixture)
  rm -f "$t/corpus/$rel"/fixture-silent/*
  corpus_selftest_case emptyfixture "$t" corpus 2 "holds no payload"

  # 6. The triple's own firing arm (verification rule 4): a unit whose silent
  #    fixture is not silent must be caught. Without this the triple is only
  #    ever observed passing.
  #    ⚠ Payload-agnostic on purpose. Naming report.txt here would bind the
  #    selftest to unit #1's filenames, and the template is CORPUS_UNITS[0] —
  #    the sorted-first unit, which changes the moment a unit sorting before
  #    provenance/ lands (WS3's corpus/coupling/ does). A hardcoded cp would
  #    then fail silently, leave the tree clean, and redden this case with
  #    "expected 1, got 0" — a red for a reason that has nothing to do with the
  #    triple.
  t=$(mk triplebreak)
  rm -f "$t/corpus/$rel"/fixture-silent/*
  cp "$t/corpus/$rel"/fixture-firing/* "$t/corpus/$rel"/fixture-silent/
  corpus_selftest_case triplebreak "$t" corpus 1 "the unit contract requires 0"

  # 7. Absent toolchain -> VOID. Specimen #5 ("missing tools must be outcome 2,
  #    not green") turned on the gate itself.
  t=$(mk notoolchain)
  corpus_selftest_case notoolchain "$t" corpus 2 "is not on PATH" "IDRIS2=/nonexistent/idris2"

  # 8. A compile that fails while printing NO ^Error: line — a crash, an OOM
  #    kill, a timeout, a signal. This is the tree that kills the error-count
  #    signal, and it is why the predicate is a conjunction rather than a grep.
  #    ⚠ MEASURED 2026-09-15: trees 1-7 are ALL survived by a predicate of
  #    `[ "$CC_ERRS" -eq 0 ]` alone, because every Idris2 failure in them is
  #    well-formed and prints ^Error:. Without this tree the suite would license
  #    "just grep the output", and the first non-Idris2 failure mode would be
  #    reported as a clean compile.
  local stub="$root/stub-idris2"
  printf '#!/bin/sh\nexit 1\n' > "$stub" && chmod +x "$stub"
  t=$(mk silentfail)
  corpus_selftest_case silentfail "$t" corpus 1 "does not compile standalone" "IDRIS2=$stub"

  # --- The three gates below were added with the modes and would otherwise
  # --- ship UNTRIPPED. A gate that has not been deliberately tripped is not a
  # --- gate, and that rule does not exempt the gates guarding the gate.

  # 9. The depth contract. A unit filed shallower than
  #    corpus/<battery>/<category>/<id>/ must be REPORTED. Marker discovery
  #    finds it at any depth precisely so this can be a loud finding rather
  #    than the silent uncounting a fixed-depth glob would produce.
  t="$root/wrongdepth"
  mkdir -p "$t/corpus/shallow"
  cp -r "$src" "$t/corpus/shallow/$(basename "$src")"
  rm -rf "$t/corpus/shallow/$(basename "$src")/build"
  corpus_selftest_case wrongdepth "$t" corpus 1 "is at depth 2"

  # 10. Declared invocation vs executed invocation. The unit still compiles and
  #     its triple still fires — the ONLY thing wrong is that the manifest's
  #     [subject_shape].build no longer names the binary the gate builds.
  t=$(mk wrongname)
  mv "$t/corpus/$rel" "$t/corpus/$(dirname "$rel")/renamed-unit"
  corpus_selftest_case wrongname "$t" corpus 1 "does not declare '-o"

  # 11. An empty corpus is NO CHECK, never "0 units, OK". A corpus root with no
  #     units that reported success would be the six-number headline's fake
  #     green at the root of the whole product.
  t="$root/emptycorpus"
  mkdir -p "$t/corpus"
  corpus_selftest_case emptycorpus "$t" corpus 2 "no corpus units found"

  # --- The LEDGER trees (mode `source`). WS1 commit C's three new gates.

  # 12. POSITIVE CONTROL for `source`. Without it, trees 13-15 would prove only
  #     that a full-tree copy can fail, not that an unmutated one passes — and
  #     a copy that was broken by construction would "pass" all three.
  mkfull cleanfull || return
  corpus_selftest_case cleanfull "$SELFTEST_TREE" source 0 "OK: every checked fact agrees"

  # 13. A STALE LEDGER. R-29 makes COUNT.a2ml generated; this is the gate that
  #     makes "generated" true rather than aspirational, and it is the red
  #     R-40 requires inside the real PR.
  mkfull staleledger || return
  sed -i 's/^deployed = "\([0-9]*\)"/deployed = "9\1"/' "$SELFTEST_TREE/corpus/COUNT.a2ml"
  corpus_selftest_case staleledger "$SELFTEST_TREE" source 1 "is stale — regenerate with: just corpus-count"

  # 14. A proven-exact WARRANT NAMING A LEMMA THAT DOES NOT EXIST. Drift, not a
  #     deficit: the tier claim is not weak, it is unfounded. Note this changes
  #     no count, so the ledger diff stays clean and only this gate fires.
  mkfull missinglemma || return
  sed -i '0,/[A-Za-z_][A-Za-z0-9_]* (Test\.idr)/s//definitelyNotALemma (Test.idr)/' \
    "$SELFTEST_TREE/corpus/$rel/error-model.a2ml"
  corpus_selftest_case missinglemma "$SELFTEST_TREE" source 1 "Test.idr declares no such lemma"

  # 15. THE THREE-SITE COUPLING commit A recorded as discipline. COUNT.a2ml is
  #     DERIVED from stability.a2ml, so regenerating the ledger can never catch
  #     a manifest that disagrees with it — the derivation does not read the
  #     manifest. Only a direct comparison can, which is why check_unit_ledger
  #     exists alongside check_corpus_count rather than inside it.
  mkfull datemismatch || return
  sed -i '/^\[adversarial\]/,/^\[/ s/^last_fired = .*/last_fired = "1970-01-01"/' \
    "$SELFTEST_TREE/corpus/$rel/manifest.a2ml"
  corpus_selftest_case datemismatch "$SELFTEST_TREE" source 1 "disagrees with stability.a2ml"

  # 16. THE ci_gate DEFICIT IS DERIVED, AND ITS RETURN IS THE PROOF. Its
  #     predecessor was a hand-written line, and a hand-written deficit is
  #     retired by whoever edits the file next — which is how a deficit gets
  #     dropped before it is discharged.
  #     ⚠ THIS TREE WAS INVERTED WHEN THE REAL WORKFLOW LANDED, and the
  #     inversion is the lesson. Until then it ADDED a workflow and expected the
  #     ledger to go stale — an expectation that silently encoded "the deficit
  #     is currently present" as an unstated premise about the repository, not
  #     about the predicate. The commit that shipped .github/workflows/
  #     corpus-check.yml discharged the deficit and turned all three ci_gate
  #     trees over at once. A tree must assert what the PREDICATE does, never
  #     what the repository currently happens to be: so this one now removes
  #     every workflow and requires the deficit to COME BACK. That is the half
  #     of "derived" no tree tested before — a predicate hard-wired to return
  #     "cleared" would have survived every earlier version of this file.
  mkfull cigate || return
  rm -rf "$SELFTEST_TREE/.github/workflows"
  corpus_selftest_case cigate "$SELFTEST_TREE" source 1 "is stale — regenerate with: just corpus-count"

  # 17. THE OTHER SPELLING ALSO DISCHARGES IT. `cleanfull` is the silence arm
  #     for the direct invocation, because the real workflow ships it; this is
  #     the silence arm for the Justfile recipe, which a workflow author writing
  #     the job by hand is at least as likely to reach for. A predicate matching
  #     only one of the two would leave the deficit standing while a real CI gate
  #     existed — the ledger understating the repository instead of overstating
  #     it, which no other tree can see, because every other tree catches the
  #     ledger claiming too much. Strip the real workflow first, so a pass here
  #     cannot be inherited from the file tree 16 removes.
  #     ⚠ The heredoc must NOT be indented with a tab-stripping <<-, and the
  #     invocation must end the line: the predicate anchors on $.
  mkfull cigatejust || return
  rm -rf "$SELFTEST_TREE/.github/workflows"
  mkdir -p "$SELFTEST_TREE/.github/workflows"
  cat > "$SELFTEST_TREE/.github/workflows/corpus-check.yml" <<'YML'
name: corpus-check
on: [push]
jobs:
  corpus:
    runs-on: ubuntu-latest
    steps:
      - run: just corpus-check
YML
  corpus_selftest_case cigatejust "$SELFTEST_TREE" source 0 "OK: every checked fact agrees"

  # 18. THE NEAR MISS MUST NOT DISCHARGE IT. Trees 16 and 17 prove the predicate
  #     is live in both directions; on their own they cannot distinguish it from
  #     one that matches any workflow mentioning the corpus at all, which would
  #     retire a deficit about units never being COMPILED in CI on the strength
  #     of a job that compiles nothing. `corpus-selftest` runs synthetic trees
  #     and `corpus-count` walks manifests; neither invokes a compiler. The
  #     deficit must therefore come back, exactly as in tree 16.
  #     The real specimen is not hypothetical: label-triage.yml carries the
  #     prose "historical corpus" in a comment, so a wildcard predicate would
  #     have been discharged by an unrelated sentence.
  mkfull cigatenear || return
  rm -rf "$SELFTEST_TREE/.github/workflows"
  mkdir -p "$SELFTEST_TREE/.github/workflows"
  cat > "$SELFTEST_TREE/.github/workflows/corpus-check.yml" <<'YML'
name: corpus-check
on: [push]
jobs:
  corpus:
    runs-on: ubuntu-latest
    steps:
      - run: just corpus-selftest
      - run: bash scripts/check-doc-facts.sh corpus-count
YML
  corpus_selftest_case cigatenear "$SELFTEST_TREE" source 1 "is stale — regenerate with: just corpus-count"

  # 19. THE COLLATION PIN IS LOAD-BEARING, AND ITS DELETION WOULD BE SILENT.
  #     `[units]` is ordered by `find … | sort`, and `sort` collates by locale.
  #     Two machines can therefore generate two different byte streams from the
  #     SAME corpus — green locally, "stale" in CI, with a diff that shows only
  #     reordered lines and explains nothing. The tie-break for [detail].last_fired
  #     moves with it, so the ledger's authority line changes too.
  #     One unit cannot expose this, so the tree builds a second: the unit id
  #     with every hyphen replaced by 'a', which C orders one way (punctuation
  #     before letters) and a UTF-8 locale the other (punctuation ignored at the
  #     primary level). The ledger is then generated twice under different
  #     inherited locales and required to come out byte-identical.
  #     ⚠ DECLARED EQUIVALENT MUTANT: pinning the WRONG locale (say
  #     en_US.utf8 instead of C) survives this tree, and correctly so —
  #     determinism holds under any pin. That choice is wrong for an
  #     AVAILABILITY reason no local test can see: on a runner lacking the
  #     locale, sort falls back to C silently and the variance returns.
  #     C and POSIX are the only locales guaranteed to exist.
  #     ⚠ This needs a second locale to exist. If none inverts the pair, the
  #     tree reports NO CHECK rather than passing — an unverifiable pin is not
  #     a verified one. Cure on a bare runner: `locale-gen en_US.UTF-8`.
  local lc_base lc_sib lc_probe lc_dir
  lc_base=$(basename "$rel")
  lc_sib="${lc_base//-/a}"
  if [ "$lc_sib" = "$lc_base" ]; then
    dead "collation selftest: unit id '$lc_base' has no hyphen, so no sibling id can be derived — the LC_ALL pin is UNVERIFIED"
  else
    lc_probe=""
    while read -r cand; do
      [ -n "$cand" ] || continue
      if [ "$(printf '%s\n%s\n' "$lc_base" "$lc_sib" | LC_ALL=C sort | head -1)" \
        != "$(printf '%s\n%s\n' "$lc_base" "$lc_sib" | LC_ALL="$cand" sort | head -1)" ]; then
        lc_probe="$cand"; break
      fi
    done < <(locale -a 2>/dev/null | grep -iE 'utf-?8$' | grep -viE '^(C|POSIX)' | sort -u)
    if [ -z "$lc_probe" ]; then
      dead "collation selftest: no available locale orders '$lc_base' and '$lc_sib' differently from C — the LC_ALL pin is UNVERIFIED (cure: locale-gen en_US.UTF-8)"
    else
      mkfull localecollate || return
      lc_dir=$(dirname "$SELFTEST_TREE/corpus/$rel")
      cp -r "$SELFTEST_TREE/corpus/$rel" "$lc_dir/$lc_sib"
      sed -i "s/${lc_base}/${lc_sib}/g" "$lc_dir/$lc_sib/manifest.a2ml"
      # ⚠ The invariant under test is DETERMINISM, not the pin's value, and it
      # must be measured without assuming the harness can impose a locale: an
      # `export` inside the script overrides an env assignment on its command
      # line, so a run cannot be forced into a locale the script has pinned.
      # (Measured — an earlier version of this tree tried exactly that and a
      # mutant pinning the WRONG locale survived it.) So generate twice, under
      # two different inherited locales, and require byte-identical output.
      # With the pin present the inherited locale is irrelevant and the bytes
      # match; with it deleted they diverge, which is the regression.
      ( cd "$SELFTEST_TREE" && LC_ALL=C CORPUS_ROOT=corpus bash "$SELFTEST_SCRIPT" corpus-count ) >/dev/null 2>&1
      cp "$SELFTEST_TREE/corpus/COUNT.a2ml" "$SELFTEST_TREE/.gen-under-C"
      ( cd "$SELFTEST_TREE" && LC_ALL="$lc_probe" CORPUS_ROOT=corpus bash "$SELFTEST_SCRIPT" corpus-count ) >/dev/null 2>&1
      if ! cmp -s "$SELFTEST_TREE/.gen-under-C" "$SELFTEST_TREE/corpus/COUNT.a2ml"; then
        bad "selftest 'localecollate' (corpus-count): the generated ledger is LOCALE-DEPENDENT — C and $lc_probe produced different bytes for the same corpus, so the committed copy can only ever be correct on one machine"
        diff -u "$SELFTEST_TREE/.gen-under-C" "$SELFTEST_TREE/corpus/COUNT.a2ml" | sed 's/^/    | /' >&2
      else
        say "selftest OK: localecollate (corpus-count) -> C and $lc_probe generate byte-identical ledgers"
      fi
      rm -f "$SELFTEST_TREE/.gen-under-C"
      # And the ledger that walk just wrote must be ACCEPTED under the other
      # locale — determinism of the generator is worth nothing if the checker
      # reads it back through a differently-ordered walk.
      corpus_selftest_case localecollate "$SELFTEST_TREE" source 0 \
        "OK: every checked fact agrees" "LC_ALL=$lc_probe"
    fi
  fi

  unset -f mk mkfull
}

# Preflight: every file this gate asserts AGAINST must exist. A missing
# assertion site is NO CHECK (exit 2), never a drift finding — a grep against
# an absent file "not matching" is the crash-reads-as-silence failure mode the
# test doctrine forbids (docs/TEST-DOCTRINE.adoc).
if [ "$MODE" = "source" ]; then
  for f in README.adoc ARCHITECTURE.adoc READINESS.adoc TEST-NEEDS.adoc DEBT.adoc \
           docs/STATE-OF-THINGS.adoc .machine_readable/descriptiles/STATE.a2ml; do
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
    check_corpus_count
    check_unit_ledger
    ;;
  report)
    check_report_facts
    ;;
  corpus)
    check_corpus
    ;;
  corpus-selftest)
    check_corpus_selftest
    ;;
  corpus-count)
    if gen_corpus_count "$CORPUS_ROOT/COUNT.a2ml"; then
      say "wrote $CORPUS_ROOT/COUNT.a2ml from a walk of $CORPUS_ROOT (${#CORPUS_UNITS[@]} unit(s))"
    fi
    ;;
  *)
    dead "unknown mode '${MODE}' (use: source | report <json> | corpus | corpus-selftest | corpus-count)"
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
