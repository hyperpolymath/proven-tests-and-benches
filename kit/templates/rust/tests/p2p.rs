// SPDX-License-Identifier: MPL-2.0
// P2P — one real seam, client -> server over loopback TCP; the double is only at
// the far end (taxonomy cat. 2).
use ptb_rust_template::{call, serve_once};
use std::net::TcpListener;
fn with_server<T>(f: impl FnOnce(std::net::SocketAddr) -> T) -> T {
    let l = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = l.local_addr().unwrap();
    let h = std::thread::spawn(move || serve_once(&l).unwrap());
    let r = f(addr); h.join().unwrap(); r
}
#[test] fn well_formed_request_round_trips() { assert_eq!(with_server(|a| call(a, "name=x").unwrap()), "OK name"); }
#[test] fn malformed_request_gets_err_not_silence() { assert_eq!(with_server(|a| call(a, "garbage").unwrap()), "ERR"); }
#[test] fn connection_to_nothing_is_an_error() {   // negative control: no server => Err
    let l = TcpListener::bind("127.0.0.1:0").unwrap(); let a = l.local_addr().unwrap(); drop(l);
    assert!(call(a, "k=v").is_err());
}
