// SPDX-License-Identifier: MPL-2.0
// BLD — the crate builds clean with warnings denied and the artefact exists
// (taxonomy cat. 4). Cheap form; CI also runs kit/lib/build-check.sh from a
// clean checkout for the timed B-BLD figure.
use std::process::Command;
#[test] fn builds_with_warnings_denied() {
    let o = Command::new(env!("CARGO")).args(["build", "--locked", "--offline", "--quiet"])
        .env("RUSTFLAGS", "-D warnings").env("CARGO_TARGET_DIR", env!("CARGO_TARGET_TMPDIR"))
        .current_dir(env!("CARGO_MANIFEST_DIR")).output().unwrap();
    assert!(o.status.success(), "{}", String::from_utf8_lossy(&o.stderr));
}
#[test] fn the_binary_artifact_exists_and_is_nonempty() {
    let p = std::path::Path::new(env!("CARGO_BIN_EXE_ptb-demo"));
    assert!(p.metadata().unwrap().len() > 0);
}
