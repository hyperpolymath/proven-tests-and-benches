// SPDX-License-Identifier: MPL-2.0
//! Demo subject. ADAPT: replace with the unit(s) under test. It exists so the
//! four sweep-1 test files below exercise something real.
use std::io::{BufRead, BufReader, Write};
use std::net::{TcpListener, TcpStream};

#[derive(Debug, PartialEq, Eq)]
pub enum ParseError { NoSeparator, EmptyKey }

/// Parse `key=value`. The value may contain `=`; the key may not be empty.
pub fn parse_kv(line: &str) -> Result<(&str, &str), ParseError> {
    let (k, v) = line.split_once('=').ok_or(ParseError::NoSeparator)?;
    if k.trim().is_empty() { return Err(ParseError::EmptyKey); }
    Ok((k.trim(), v))
}

/// Serve one `key=value` request on `listener`, reply `OK key` or `ERR`.
pub fn serve_once(listener: &TcpListener) -> std::io::Result<()> {
    let (stream, _) = listener.accept()?;
    let mut line = String::new();
    BufReader::new(&stream).read_line(&mut line)?;
    let reply = match parse_kv(line.trim_end()) { Ok((k, _)) => format!("OK {k}\n"), Err(_) => "ERR\n".to_string() };
    (&stream).write_all(reply.as_bytes())
}

/// Client half of the seam.
pub fn call(addr: std::net::SocketAddr, line: &str) -> std::io::Result<String> {
    let mut s = TcpStream::connect(addr)?;
    let limit = Some(std::time::Duration::from_secs(5));   // a silent peer is a failure, not a hang
    s.set_read_timeout(limit)?; s.set_write_timeout(limit)?;
    s.write_all(format!("{line}\n").as_bytes())?;
    let mut out = String::new();
    BufReader::new(s).read_line(&mut out)?;
    if out.is_empty() { return Err(std::io::ErrorKind::UnexpectedEof.into()); }   // peer closed without replying
    Ok(out.trim_end().to_string())
}
