// SPDX-License-Identifier: MPL-2.0
// Sweep-1 template for Gleam: UT, SMK, BLD, P2P. ADAPT: replace parse_kv.
// Run: gleam test (needs gleeunit in gleam.toml dev-dependencies).
// NOT EXECUTED in the foundation container (no gleam).
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() { gleeunit.main() }

pub type ParseError { NoSeparator EmptyKey }

pub fn parse_kv(s: String) -> Result(#(String, String), ParseError) {
  case string.split_once(s, "=") {
    Error(_) -> Error(NoSeparator)
    Ok(#(k, v)) ->
      case string.trim(k) {
        "" -> Error(EmptyKey)
        key -> Ok(#(key, v))
      }
  }
}

// UT
pub fn ut_splits_on_first_equals_test() { parse_kv("a=b=c") |> should.equal(Ok(#("a", "b=c"))) }
pub fn ut_no_separator_test() { parse_kv("kv") |> should.equal(Error(NoSeparator)) }
pub fn ut_empty_key_test() { parse_kv(" =v") |> should.equal(Error(EmptyKey)) }
// SMK: module loads and answers (CI: `gleam build` then run the entry point)
pub fn smk_answers_test() { parse_kv("k=v") |> result.is_ok |> should.be_true }
// BLD: this file compiling under `gleam test` is the build gate; CI also runs `gleam build --warnings-as-errors`
pub fn bld_compiled_test() { should.be_true(True) }
// P2P: two functions across one seam (encode -> decode) round-trip
fn encode(k: String, v: String) -> String { k <> "=" <> v }
pub fn p2p_roundtrip_test() { encode("name", "x") |> parse_kv |> should.equal(Ok(#("name", "x"))) }
