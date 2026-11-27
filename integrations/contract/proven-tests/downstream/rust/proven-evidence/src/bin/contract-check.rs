// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// CLI for the downstream integration contract checker (see src/contract.rs).
// Exit 0 held, 1 wrong verdict, 2 NO CHECK WAS PERFORMED.

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let root = proven_evidence::contract::default_root();
    std::process::exit(proven_evidence::contract::main_with(&root, &args));
}
