// SPDX-License-Identifier: MPL-2.0
// SMK — the built binary starts, answers, exits 0 (taxonomy cat. 8).
use std::process::Command;
fn bin() -> Command { Command::new(env!("CARGO_BIN_EXE_ptb-demo")) }
#[test] fn version_runs_and_prints() {
    let o = bin().arg("--version").output().unwrap();
    assert!(o.status.success());
    assert!(String::from_utf8_lossy(&o.stdout).starts_with("ptb-demo "));
}
#[test] fn bad_input_exits_nonzero_not_zero() {   // negative control
    let o = bin().arg("novalue").output().unwrap();
    assert!(!o.status.success());
}
