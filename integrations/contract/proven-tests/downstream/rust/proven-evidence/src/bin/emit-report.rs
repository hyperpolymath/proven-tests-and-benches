// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// emit-report <tests.json> <report.json>: write a schema_version-2 run report
// derived from a flat list of executed tests (see src/emit.rs).
// Exit 0 written, 1 dishonest or malformed fact, 2 input unreadable.

use std::process::exit;

fn die(message: &str, code: i32) -> ! {
    eprintln!("emit-report: {message}");
    exit(code);
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: emit-report <tests.json> <report.json>");
        exit(2);
    }
    let raw = std::fs::read_to_string(&args[1])
        .unwrap_or_else(|e| die(&format!("cannot read {}: {e}", args[1]), 2));
    let doc: serde_json::Value = serde_json::from_str(&raw)
        .unwrap_or_else(|e| die(&format!("{} is not valid JSON: {e}", args[1]), 2));
    let report = proven_evidence::emit::emit(&doc).unwrap_or_else(|r| die(&r.message, r.code));
    let text = serde_json::to_string_pretty(&report).unwrap_or_else(|e| die(&e.to_string(), 1));
    std::fs::write(&args[2], text + "\n")
        .unwrap_or_else(|e| die(&format!("cannot write {}: {e}", args[2]), 1));
    let s = &report["summary"];
    println!(
        "wrote {}: {}/{} passed, {} covered cell(s)",
        args[2], s["passed"], s["total"], s["covered_cells"]
    );
}
