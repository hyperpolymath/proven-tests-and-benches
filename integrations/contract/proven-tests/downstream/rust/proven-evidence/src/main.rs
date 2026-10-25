// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// CLI over the downstream Proven-Tests integration contract, built on the
// library in src/lib.rs:
//
//   proven-evidence emit  <report.json> <summary.json>   derive the summary
//   proven-evidence check <report.json> <summary.json>  refuse a summary that
//                                                        disagrees with its entries
//
// The summary is a DERIVED view. `emit` never copies a coverage claim out of
// the report: it recomputes it from the entries whose outcome is `passed`.
//
// EXIT CODES (the repository's standing three-outcome convention):
//   0  the report is conformant and the summary matches it
//   1  the contract is not met — the report has violations, or the summary
//      disagrees with the entries
//   2  NO CHECK WAS PERFORMED — the input could not be read or parsed, or the
//      CLI was used wrong. Never reported as success.

use serde_json::Value;
use std::process::exit;

/// Print the accepted emit and check command forms to stderr.
fn usage() {
    eprintln!("usage: proven-evidence emit <report.json> <summary.json>");
    eprintln!("       proven-evidence check <report.json> <summary.json>");
}

/// Read a UTF-8 JSON file, returning Err for file access, decoding or JSON errors.
fn read_json(path: &str) -> Result<Value, String> {
    let raw = std::fs::read_to_string(path).map_err(|e| format!("cannot read {path}: {e}"))?;
    let value: Value = serde_json::from_str(&raw)
        .map_err(|e| format!("{path} is not valid JSON: {e}"))?;
    Ok(value)
}

/// Validate a report before emitting or checking its summary.
///
/// Exit 0 on success, 1 for violations, a summary mismatch or an output failure,
/// and 2 for invalid arguments or unreadable or malformed input.
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (mode, input) = match args.get(1).map(String::as_str) {
        Some("emit") if args.len() == 4 => (Mode::Emit, args[2].clone()),
        Some("check") if args.len() == 4 => (Mode::Check, args[2].clone()),
        _ => {
            usage();
            exit(2);
        }
    };

    // Structural failures mean no check was performed.
    let doc = match read_json(&input) {
        Ok(doc) => doc,
        Err(message) => {
            eprintln!("proven-evidence: {message}");
            exit(2);
        }
    };
    let report = match proven_evidence::parse(&doc) {
        Ok(report) => report,
        Err(message) => {
            eprintln!("proven-evidence: {input}: {message}");
            exit(2);
        }
    };
    let violations = match proven_evidence::validate(&doc) {
        Ok(violations) => violations,
        Err(message) => {
            eprintln!("proven-evidence: {input}: {message}");
            exit(2);
        }
    };
    if !violations.is_empty() {
        eprintln!("proven-evidence: {input} is not conformant:");
        for v in violations {
            eprintln!("  - {v}");
        }
        exit(1);
    }

    match mode {
        Mode::Emit => emit_summary(&input, &args[3], &doc, &report),
        Mode::Check => check_summary(&input, &args[3], &report),
    }
}

#[derive(Clone, Copy)]
enum Mode {
    Emit,
    Check,
}

/// Read `summary.cat_aspect_cells`, defaulting to LATTICE_CELLS when absent
/// or not representable as an i64. Negative values are returned unchanged.
fn lattice_cells(doc: &Value) -> i64 {
    doc.get("summary")
        .and_then(|s| s.get("cat_aspect_cells"))
        .and_then(Value::as_i64)
        .unwrap_or(proven_evidence::LATTICE_CELLS)
}

/// Derive the summary from the entries and write it.
///
/// Overwrite `output` with pretty JSON using the lattice size from `doc`.
/// Exit 0 on success or 1 on serialisation or write failure.
fn emit_summary(input: &str, output: &str, doc: &Value, report: &proven_evidence::Report) -> ! {
    let summary = proven_evidence::summarise(&report.entries, lattice_cells(doc));
    let text = match serde_json::to_string_pretty(&summary) {
        Ok(text) => text,
        Err(e) => {
            eprintln!("proven-evidence: cannot serialise summary: {e}");
            exit(1);
        }
    };
    if let Err(e) = std::fs::write(output, text + "\n") {
        eprintln!("proven-evidence: cannot write {output}: {e}");
        exit(1);
    }
    println!(
        "proven-evidence: emitted {output} ({} passed, {} of {} cells covered)",
        summary.passed, summary.covered_cells, summary.cat_aspect_cells
    );
    exit(0);
}

/// Refuse a submitted summary that disagrees with the report's entries.
///
/// Read `summary_path`. The submitted lattice size is reused without checking
/// it against the report. Exit 0 for a match, 1 for a mismatch, or 2 if the
/// summary cannot be read or deserialised.
fn check_summary(
    input: &str,
    summary_path: &str,
    report: &proven_evidence::Report,
) -> ! {
    let raw = match std::fs::read_to_string(summary_path) {
        Ok(raw) => raw,
        Err(e) => {
            eprintln!("proven-evidence: cannot read {summary_path}: {e}");
            exit(2);
        }
    };
    let submitted: proven_evidence::Summary = match serde_json::from_str(&raw) {
        Ok(summary) => summary,
        Err(e) => {
            eprintln!("proven-evidence: {summary_path} is not a valid summary: {e}");
            exit(2);
        }
    };
    if let Err(e) = proven_evidence::assert_summary_matches(&report.entries, &submitted) {
        eprintln!("proven-evidence: {summary_path}: {e}");
        exit(1);
    }
    println!(
        "proven-evidence: {summary_path} matches the entries in {input}"
    );
    exit(0);
}
