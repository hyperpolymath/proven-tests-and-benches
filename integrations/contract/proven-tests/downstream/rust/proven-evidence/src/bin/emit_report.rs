// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// emit-report <tests.json> <report.json>: turn executed test facts into a
// schema_version-2 report. Exit 0 written; 1 a test fact is dishonest or
// malformed; 2 the input could not be read or parsed (NO CHECK WAS PERFORMED).

use proven_evidence::emit::{emit, EmitError};
use std::process::exit;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: emit-report <tests.json> <report.json>");
        exit(2);
    }
    let raw = std::fs::read_to_string(&args[1]).unwrap_or_else(|e| {
        eprintln!("emit_report: cannot read {}: {e}", args[1]);
        exit(2)
    });
    let doc: serde_json::Value = serde_json::from_str(&raw).unwrap_or_else(|e| {
        eprintln!("emit_report: {} is not valid JSON: {e}", args[1]);
        exit(2)
    });
    let report = match emit(&doc) {
        Ok(r) => r,
        Err(EmitError::NoCheck(m)) => {
            eprintln!("emit_report: {m}");
            exit(2)
        }
        Err(EmitError::Dishonest(m)) => {
            eprintln!("emit_report: {m}");
            exit(1)
        }
    };
    let text = serde_json::to_string_pretty(&report).expect("report serialises");
    if let Err(e) = std::fs::write(&args[2], text + "\n") {
        eprintln!("emit_report: cannot write {}: {e}", args[2]);
        exit(2);
    }
    let s = &report["summary"];
    println!("wrote {}: {}/{} passed, {} covered cell(s)", args[2], s["passed"], s["total"], s["covered_cells"]);
}
