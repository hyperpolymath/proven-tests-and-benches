# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
ExUnit.start()

Code.require_file(
  "../lib/proven_tests/contract/manifest_binding.ex",
  __DIR__
)

defmodule ProvenTests.Contract.ManifestBindingTest do
  use ExUnit.Case, async: true

  alias ProvenTests.Contract.ManifestBinding

  test "exact source binding is accepted" do
    assert ManifestBinding.violations(
             [%{"module" => "A.Test", "file" => "test/a_test.exs"}],
             [%{module: "A.Test", file: "test/a_test.exs"}]
           ) == []
  end

  test "an existing but unrelated path cannot validate a declaration" do
    problems =
      ManifestBinding.violations(
        [%{"module" => "A.Test", "file" => "test/unrelated_test.exs"}],
        [%{module: "A.Test", file: "test/a_test.exs"}]
      )

    assert [problem] = problems
    assert problem =~ "test/unrelated_test.exs"
    assert problem =~ "test/a_test.exs"
  end

  test "duplicate definitions are not silently resolved by last-write-wins" do
    problems =
      ManifestBinding.violations(
        [%{"module" => "A.Test", "file" => "test/a_test.exs"}],
        [
          %{module: "A.Test", file: "test/a_test.exs"},
          %{module: "A.Test", file: "test/shadow_test.exs"}
        ]
      )

    assert [problem] = problems
    assert problem =~ "ambiguous source definitions"
  end

  test "absent modules are reserved for the compulsory stale-entry check" do
    assert ManifestBinding.violations(
             [%{"module" => "Missing.Test", "file" => "test/missing_test.exs"}],
             []
           ) == []
  end
end
