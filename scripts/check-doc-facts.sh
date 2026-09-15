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
#                                 runs `corpus` against synthetic trees that
#                                 MUST trip it. A gate that has not been
#                                 deliberately tripped is not a gate
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
corpus_discover() { # populates CORPUS_UNITS[]
  CORPUS_UNITS=()
  [ -d "$CORPUS_ROOT" ] || { dead "corpus root '$CORPUS_ROOT' does not exist"; return 1; }
  mapfile -t CORPUS_UNITS < <(find "$CORPUS_ROOT" -type f -name manifest.a2ml -printf '%h\n' | sort)
  if [ "${#CORPUS_UNITS[@]}" -eq 0 ]; then
    # Zero units is NO CHECK, never "0 units, all fine". An empty corpus that
    # reported OK would be the six-number headline's fake green at the root.
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
# A gate that has not been deliberately tripped is not a gate. Eleven synthetic
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
corpus_selftest_case() { # <name> <tree> <want-rc> <want-substring> [env-assignment]
  local case_name="$1" tree="$2" want="$3" pin="$4" envset="${5:-}"
  local out rc
  if [ -n "$envset" ]; then
    out=$(cd "$tree" && env "$envset" CORPUS_ROOT=corpus bash "$SELFTEST_SCRIPT" corpus 2>&1)
  else
    out=$(cd "$tree" && CORPUS_ROOT=corpus bash "$SELFTEST_SCRIPT" corpus 2>&1)
  fi
  rc=$?
  if [ "$rc" -ne "$want" ]; then
    bad "selftest '$case_name': expected exit ${want}, got ${rc}"
    printf '%s\n' "$out" | sed 's/^/    | /' >&2
    return
  fi
  if ! printf '%s\n' "$out" | grep -qF -- "$pin"; then
    bad "selftest '$case_name': exit ${rc} was right but the reason was not — expected output containing: ${pin}"
    printf '%s\n' "$out" | sed 's/^/    | /' >&2
    return
  fi
  say "selftest OK: $case_name -> exit ${rc}, pinned reason present"
}

check_corpus_selftest() {
  if ! command -v "$IDRIS2" >/dev/null 2>&1; then
    dead "toolchain '$IDRIS2' is not on PATH — the selftest cannot compile anything"
    return
  fi
  corpus_discover || return
  local src="${CORPUS_UNITS[0]}" root
  SELFTEST_SCRIPT=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
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

  local t

  # 1. POSITIVE CONTROL. Without this the six red trees below prove only that
  #    the gate can say no, not that it can ever say yes — a gate stuck at
  #    "fail" would pass every negative case.
  t=$(mk clean)
  corpus_selftest_case clean "$t" 0 "OK: every checked fact agrees"

  # 2. Bad import: rc=0 on a FAILED compile. The row that breaks `&&`.
  t=$(mk badimport)
  sed -i '0,/^module Test$/s//module Test\nimport ProvenTests.Types/' "$t/corpus/$rel/Test.idr"
  corpus_selftest_case badimport "$t" 1 "does not compile standalone"

  # 3. Type error: rc=1 but a binary IS emitted. The row that breaks a
  #    binary-presence test.
  t=$(mk typeerr)
  printf '\nselftestCanary : Nat\nselftestCanary = "not a Nat"\n' >> "$t/corpus/$rel/Test.idr"
  corpus_selftest_case typeerr "$t" 1 "does not compile standalone"

  # 4. Incomplete spine -> VOID, never uncounted.
  t=$(mk nospine)
  rm -f "$t/corpus/$rel/depends.a2ml"
  corpus_selftest_case nospine "$t" 2 "incomplete unit contract — 'depends.a2ml' is missing"

  # 5. Empty fixture directory -> VOID. The loop would otherwise check nothing
  #    and report success.
  t=$(mk emptyfixture)
  rm -f "$t/corpus/$rel"/fixture-silent/*
  corpus_selftest_case emptyfixture "$t" 2 "holds no payload"

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
  corpus_selftest_case triplebreak "$t" 1 "the unit contract requires 0"

  # 7. Absent toolchain -> VOID. Specimen #5 ("missing tools must be outcome 2,
  #    not green") turned on the gate itself.
  t=$(mk notoolchain)
  corpus_selftest_case notoolchain "$t" 2 "is not on PATH" "IDRIS2=/nonexistent/idris2"

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
  corpus_selftest_case silentfail "$t" 1 "does not compile standalone" "IDRIS2=$stub"

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
  corpus_selftest_case wrongdepth "$t" 1 "is at depth 2"

  # 10. Declared invocation vs executed invocation. The unit still compiles and
  #     its triple still fires — the ONLY thing wrong is that the manifest's
  #     [subject_shape].build no longer names the binary the gate builds.
  t=$(mk wrongname)
  mv "$t/corpus/$rel" "$t/corpus/$(dirname "$rel")/renamed-unit"
  corpus_selftest_case wrongname "$t" 1 "does not declare '-o"

  # 11. An empty corpus is NO CHECK, never "0 units, OK". A corpus root with no
  #     units that reported success would be the six-number headline's fake
  #     green at the root of the whole product.
  t="$root/emptycorpus"
  mkdir -p "$t/corpus"
  corpus_selftest_case emptycorpus "$t" 2 "no corpus units found"

  unset -f mk
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
  *)
    dead "unknown mode '${MODE}' (use: source | report <json> | corpus | corpus-selftest)"
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
