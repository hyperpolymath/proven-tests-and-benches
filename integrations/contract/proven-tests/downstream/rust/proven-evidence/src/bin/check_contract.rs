// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// Downstream evidence contract checker.
//
//   check-contract [--root <contract-dir>] <proven-tests|cicd-squabbler>
//   check-contract [--root <contract-dir>] validate-file <path> <surface>
//
// <contract-dir> holds the per-surface cases.json and fixtures; it defaults to
// integrations/contract relative to the current directory.
// Exit: 0 held, 1 wrong verdict, 2 NO CHECK WAS PERFORMED.

use proven_evidence::runner::{run_surface, validate_file, Surface};
use std::path::PathBuf;
use std::process::exit;

fn usage() -> ! {
    println!("Downstream evidence contract checker");
    println!("\nusage: check-contract [--root <dir>] <proven-tests|cicd-squabbler>");
    println!("       check-contract [--root <dir>] validate-file <path> <proven-tests|cicd-squabbler>");
    exit(2);
}

fn main() {
    let mut args: Vec<String> = std::env::args().skip(1).collect();
    let mut root = PathBuf::from("integrations/contract");
    if args.first().map(String::as_str) == Some("--root") {
        if args.len() < 2 {
            usage();
        }
        root = PathBuf::from(args.remove(1));
        args.remove(0);
    }
    let mut stdout = std::io::stdout();
    let result = match args.iter().map(String::as_str).collect::<Vec<_>>().as_slice() {
        [s] if Surface::parse(s).is_some() => run_surface(&root, Surface::parse(s).unwrap(), &mut stdout),
        ["validate-file", path, s] if Surface::parse(s).is_some() => {
            validate_file(&PathBuf::from(path), Surface::parse(s).unwrap(), &mut stdout)
        }
        _ => usage(),
    };
    match result {
        Ok(code) => exit(code),
        Err(e) => {
            println!("NO CHECK PERFORMED: {e}");
            exit(2);
        }
    }
}
