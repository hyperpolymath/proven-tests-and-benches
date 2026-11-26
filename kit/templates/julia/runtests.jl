# SPDX-License-Identifier: MPL-2.0
# Sweep-1 template for Julia: UT, SMK, BLD, P2P. ADAPT: replace `Subject`.
# NOT EXECUTED in the foundation container (no julia). Treat as unverified until
# a consumer's first CI run; report back through the F1 thread.
using Test, Sockets

module Subject
parse_kv(s) = begin
    i = findfirst('=', s); i === nothing && throw(ArgumentError("no separator"))
    k = strip(s[1:i-1]); isempty(k) && throw(ArgumentError("empty key"))
    (k, s[i+1:end])
end
end

@testset "UT" begin
    @test Subject.parse_kv("a=b=c") == ("a", "b=c")
    @test Subject.parse_kv("k=") == ("k", "")
    @test_throws ArgumentError Subject.parse_kv("kv")
    @test_throws ArgumentError Subject.parse_kv(" =v")
end
@testset "SMK" begin   # ADAPT: run your real entry point
    out = read(`$(Base.julia_cmd()) -e "println(:ok)"`, String)
    @test strip(out) == "ok"
end
@testset "BLD" begin   # package precompiles
    @test success(`$(Base.julia_cmd()) --project=. -e "using Pkg; Pkg.precompile()"`) || @warn "ADAPT: set --project to your package"
end
@testset "P2P" begin   # loopback seam, double at the far end only
    srv = listen(IPv4(127,0,0,1), 0); port = getsockname(srv)[2]
    t = @async (c = accept(srv); println(c, "OK ", strip(readline(c))); close(c))
    c = connect(port); println(c, "name"); @test readline(c) == "OK name"; close(c); wait(t); close(srv)
end
