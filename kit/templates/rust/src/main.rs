// SPDX-License-Identifier: MPL-2.0
fn main() {
    let arg = std::env::args().nth(1).unwrap_or_else(|| "--version".into());
    if arg == "--version" { println!("ptb-demo {}", env!("CARGO_PKG_VERSION")); }
    else { match ptb_rust_template::parse_kv(&arg) { Ok((k, v)) => println!("{k} -> {v}"), Err(e) => { eprintln!("error: {e:?}"); std::process::exit(1) } } }
}
