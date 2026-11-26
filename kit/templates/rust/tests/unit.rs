// SPDX-License-Identifier: MPL-2.0
// UT — every public function, every error branch (taxonomy cat. 1).
use ptb_rust_template::{parse_kv, ParseError};
#[test] fn splits_on_first_equals() { assert_eq!(parse_kv("a=b=c"), Ok(("a", "b=c"))); }
#[test] fn trims_the_key() { assert_eq!(parse_kv("  k =v"), Ok(("k", "v"))); }
#[test] fn empty_value_is_allowed() { assert_eq!(parse_kv("k="), Ok(("k", ""))); }
#[test] fn no_separator_is_an_error() { assert_eq!(parse_kv("kv"), Err(ParseError::NoSeparator)); }
#[test] fn empty_key_is_an_error() { assert_eq!(parse_kv(" =v"), Err(ParseError::EmptyKey)); }
