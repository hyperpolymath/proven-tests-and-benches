-- SPDX-License-Identifier: MPL-2.0
--
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
--

module ProvenSubject.GoldenVectors

import ProvenTests.Tropical
import Data.List
import Data.List1
import Data.String

%default total

-- =============================================================================
-- GOLDEN VECTORS — the FFI-parity harness fixture
-- =============================================================================
-- A golden vector is an input/expected pair computed by an Idris ORACLE whose
-- provenance is known. A future FFI-parity harness (see docs/FFI-PARITY-DESIGN.adoc)
-- feeds each input to every proven language binding and asserts the binding
-- returns `expected` — so "the same operation in 120 bindings produces identical
-- results" (proven's TEST-NEEDS.md gap) becomes a mechanical check.
--
-- The oracle here is the framework's own min-plus semiring, whose laws are
-- Actually-Proven (ProvenTests.Tropical, total proofs). These integer min/plus
-- vectors mirror proven's SafeMath surface; when proven ships a real
-- Idris-backed libproven, swap this oracle for its SafeMath/SafeCurrency
-- functions without changing the harness or the JSONL schema.

record Vector where
  constructor MkVector
  fn       : String
  inputs   : List Integer
  expected : String

-- Oracle: min over naturals (the ⊕ primitive), as an Integer surface.
oracleMin : Nat -> Nat -> Nat
oracleMin = minN

-- Oracle: saturating/plus over naturals (the ⊗ primitive).
oraclePlus : Nat -> Nat -> Nat
oraclePlus a b = a + b

natToI : Nat -> Integer
natToI = cast

iToNat : Integer -> Nat
iToNat = integerToNat

pair : String -> Nat -> Nat -> (Nat -> Nat -> Nat) -> Vector
pair name a b f = MkVector name [natToI a, natToI b] (show (natToI (f a b)))

--/ The reference vectors. Deterministic, small, and edge-inclusive (zeros,
--/ equal operands, asymmetry).
export
vectors : List Vector
vectors =
  [ pair "min_plus.min" 0 3 oracleMin
  , pair "min_plus.min" 5 5 oracleMin
  , pair "min_plus.min" 9 1 oracleMin
  , pair "min_plus.min" 2 8 oracleMin
  , pair "min_plus.plus" 0 0 oraclePlus
  , pair "min_plus.plus" 7 4 oraclePlus
  , pair "min_plus.plus" 100 1 oraclePlus
  , pair "min_plus.plus" 3 3 oraclePlus
  ]

-- minimal JSON string escaping (our values are digits + known names, so this
-- is a straight quote of already-safe content)
q : String -> String
q s = "\"" ++ s ++ "\""

vecToJsonl : Vector -> String
vecToJsonl v =
  "{" ++ q "module" ++ ":" ++ q "min_plus"
      ++ "," ++ q "function" ++ ":" ++ q (fn v)
      ++ "," ++ q "input" ++ ":[" ++ joinInts (inputs v) ++ "]"
      ++ "," ++ q "expected" ++ ":" ++ expected v
      ++ "," ++ q "oracle_provenance" ++ ":" ++ q "ActuallyProven:ProvenTests.Tropical"
      ++ "}"
  where
    joinInts : List Integer -> String
    joinInts xs = concat (intersperse "," (map show xs))

-- ── proven SafeBase64 vectors (string I/O; oracle = RFC 4648) ────────────────
-- Sourced from proven's own tests/unit/SafeBase64Unit.idr. proven cannot be
-- linked here (its ipkg includes 47 non-compiling WIP modules and does not
-- install in reasonable time), so we capture the module's *expected behaviour*
-- as golden vectors. The oracle is the RFC, not a machine-checked proof, so
-- these are provenance-tagged "Provisionally" — a deliberate contrast with the
-- ActuallyProven min-plus vectors above. The FFI-parity runner will execute
-- them against proven's SafeBase64 binding once a real libproven exists.

record StrVector where
  constructor MkStrVector
  fn       : String
  input    : String
  expected : String

b64 : String -> String -> StrVector
b64 = MkStrVector "SafeBase64.encode_standard"

export
base64Vectors : List StrVector
base64Vectors =
  [ b64 ""             ""
  , b64 "f"            "Zg=="
  , b64 "fo"           "Zm8="
  , b64 "foo"          "Zm9v"
  , b64 "foobar"       "Zm9vYmFy"
  , b64 "Hello, World!" "SGVsbG8sIFdvcmxkIQ=="
  ]

strVecToJsonl : StrVector -> String
strVecToJsonl v =
  "{" ++ q "module" ++ ":" ++ q "SafeBase64"
      ++ "," ++ q "function" ++ ":" ++ q (fn v)
      ++ "," ++ q "input" ++ ":" ++ q (input v)
      ++ "," ++ q "expected" ++ ":" ++ q (expected v)
      ++ "," ++ q "oracle_provenance" ++ ":" ++ q "ProvisionallyProven:RFC-4648"
      ++ "," ++ q "note" ++ ":" ++ q "from proven tests/unit/SafeBase64Unit.idr; awaiting FFI runner"
      ++ "}"

--/ The whole fixture as JSONL (one vector per line): the ActuallyProven min-plus
--/ oracle vectors, then the Provisionally-graded proven SafeBase64 vectors.
export
goldenJsonl : String
goldenJsonl = unlines (map vecToJsonl vectors ++ map strVecToJsonl base64Vectors)
