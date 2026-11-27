# SPDX-License-Identifier: MPL-2.0
# Sweep-1 template for Elixir: UT, SMK, BLD, P2P. ADAPT: replace Subject.
# Run: mix test. NOT EXECUTED in the foundation container (no elixir).
defmodule Subject do
  def parse_kv(s) do
    case String.split(s, "=", parts: 2) do
      [k, v] -> if String.trim(k) == "", do: {:error, :empty_key}, else: {:ok, {String.trim(k), v}}
      _ -> {:error, :no_separator}
    end
  end
end

defmodule PtbSweep1Test do
  use ExUnit.Case, async: true
  @moduletag :sweep1

  test "UT splits on first equals", do: assert Subject.parse_kv("a=b=c") == {:ok, {"a", "b=c"}}
  test "UT error branches" do
    assert Subject.parse_kv("kv") == {:error, :no_separator}
    assert Subject.parse_kv(" =v") == {:error, :empty_key}
  end
  test "SMK the application starts" do   # ADAPT: Application.ensure_all_started(:your_app)
    assert {:ok, _} = Application.ensure_all_started(:logger)
  end
  test "BLD compiles with warnings as errors" do   # run in CI: mix compile --warnings-as-errors --force
    assert Code.ensure_loaded?(Subject)
  end
  test "P2P two processes, one seam, double at the far end only" do
    parent = self()
    pid = spawn(fn -> receive do {:req, from, line} -> send(from, {:resp, Subject.parse_kv(line)}) end end)
    send(pid, {:req, parent, "name=x"})
    assert_receive {:resp, {:ok, {"name", "x"}}}, 1000
  end
  test "P2P negative control: no reply is a timeout, not a pass" do
    refute_receive {:resp, _}, 50
  end
end
