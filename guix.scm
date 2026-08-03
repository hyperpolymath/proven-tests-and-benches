;; SPDX-License-Identifier: MPL-2.0
;; SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
;;
;; guix.scm — development environment for proven-tests-and-benches
;;
;; Usage:
;;   guix shell -D -f guix.scm      ; drop into a shell with the build inputs
;;   just deps                      ; then bootstrap Idris2 from source
;;   just ci                        ; then run the full gate
;;
;; ---------------------------------------------------------------------------
;; WHAT THIS IS, AND WHAT IT IS NOT
;; ---------------------------------------------------------------------------
;; This defines the *environment needed to build this repository*, not a Guix
;; package of the library itself. That distinction is deliberate and honest:
;;
;;   * GNU Guix does not ship an `idris2' package (it ships `idris', which is
;;     Idris 1 — a different, incompatible language). There is therefore no
;;     Guix input that can supply this repository's compiler.
;;
;;   * The compiler is bootstrapped from source by scripts/install-idris2.sh,
;;     against the Chez Scheme backend. That script needs exactly the inputs
;;     named below: chez-scheme (invoked at BUILD time, not merely to
;;     bootstrap), gmp, a C toolchain, make, git and coreutils.
;;
;; So `guix shell -D -f guix.scm' gets you a reproducible environment in which
;; `just deps' will succeed. It does not, by itself, produce a built artefact.
;; Claiming otherwise would be the kind of unearned reproducibility claim this
;; repository exists to detect.
;;
;; ---------------------------------------------------------------------------
;; PROVENANCE WARNING — read before "updating" this file
;; ---------------------------------------------------------------------------
;; Do NOT replace this file by copying a sibling's guix.scm. An estate-wide
;; sweep propagated a single guix.scm into ~182 repositories, overwriting both
;; the package IDENTITY and the LICENCE. Repositories still carry the damage:
;; as of 2026-08-03, hyper-repos/proven/guix.scm declares (name "squisher-corpus")
;; under PMPL-1.0-or-later, which is neither its name nor its licence.
;;
;; This repository is MPL-2.0 (code) and CC-BY-SA-4.0 (docs). PMPL-1.0 applies
;; to exactly three estate repositories, none of which is this one.
;;
;; ---------------------------------------------------------------------------
;; VALIDATION STATUS
;; ---------------------------------------------------------------------------
;; NOT yet validated by a `guix shell' run: Guix is not installed on the
;; machine where this file was authored (2026-08-03), so it has been written
;; against the documented requirements of scripts/install-idris2.sh rather than
;; confirmed by execution. Treat the input list as reviewed-but-untested until
;; someone records a successful `guix shell -D -f guix.scm && just ci' here.

(use-modules (guix packages)
             (guix build-system gnu)
             (guix gexp)
             (guix git-download)          ; git-predicate
             ((guix licenses) #:prefix license:)
             (gnu packages base)          ; gnu-make, coreutils
             (gnu packages bash)          ; bash-minimal
             (gnu packages chez)          ; chez-scheme
             (gnu packages commencement)  ; gcc-toolchain
             (gnu packages multiprecision); gmp
             (gnu packages version-control) ; git
             (gnu packages rust-apps))    ; just

(package
  (name "proven-tests-and-benches")
  (version "0.1.0")
  (source (local-file "." "proven-tests-and-benches-checkout"
                      #:recursive? #t
                      #:select? (git-predicate (current-source-directory))))
  (build-system gnu-build-system)
  (arguments
   ;; No Guix-native build: the compiler must be bootstrapped first (see above).
   ;; The phases are disabled rather than faked, so this cannot report a
   ;; successful build it did not perform.
   (list #:tests? #f
         #:phases
         #~(modify-phases %standard-phases
             (delete 'configure)
             (delete 'build)
             (delete 'install)
             (delete 'check))))
  (inputs
   (list chez-scheme          ; Idris2's backend; invoked at build time
         gmp))                ; libgmp — required by the Idris2 runtime
  (native-inputs
   (list gcc-toolchain        ; cc, ld
         gnu-make             ; scripts/install-idris2.sh drives `make'
         git                  ; installer clones the Idris2 release tag
         bash-minimal
         coreutils
         just))               ; the task runner every recipe here goes through
  (synopsis "Idris2 testing and benchmarking framework with machine-checked warrants")
  (description
   "proven-tests-and-benches is the Hyperpolymath estate's testing and
benchmarking framework, written in Idris2.  A test's warrant — the strength of
the evidence behind it — is a first-class value checked by the type system
rather than a label: the Actually-Proven provenance tier structurally requires
a non-empty ladder of machine-checked proof steps, so it cannot be claimed
without justification.  Coverage is derived from tests that actually ran and
passed at typed lattice coordinates, and the derivation itself is proved, so a
covered cell cannot be asserted by hand.")
  (home-page "https://github.com/hyperpolymath/proven-tests-and-benches")
  ;; Code is MPL-2.0; prose under docs/ is CC-BY-SA-4.0 (see REUSE.toml).
  (license license:mpl2.0))
