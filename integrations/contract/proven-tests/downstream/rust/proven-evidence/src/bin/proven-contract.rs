// SPDX-License-Identifier: MPL-2.0
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
//
// CLI over the downstream integration contract checker and emitter. It replaces
// the former Python check_contract.py and emit_report.py.
//
//   proven-contract <proven-tests|cicd-squabbler>
//       run the fixture cases for a surface
//   proven-contract validate-file <path> <proven-tests|cicd-squabbler>
//       judge one report or gate file
//   proven-contract emit-report <tests.json> <report.json>
//       turn a flat list of test facts into a schema_version-2 run report
//
// EXIT CODES: 0 conformant / written; 1 the contract is not met; 2 NO CHECK
// WAS PERFORMED (missing or unparseable input, wrong command line).

use proven_evidence::contract_check;
use std::io::Write;
use std::process::exit;

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    let code = if args.first().map(String::as_str) == Some("emit-report") {
        let stderr = std::io::stderr();
        contract_check::emit_main(&args[1..], &mut out, &mut stderr.lock())
    } else {
        contract_check::check_main(&args, &contract_check::default_root(), &mut out)
    };
    let _ = out.flush();
    exit(code);
}
