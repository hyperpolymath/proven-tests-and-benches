# SPDX-License-Identifier: MPL-2.0
#  SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
defmodule ProvenTests.Contract.ManifestBinding do
  @moduledoc """
  Reusable adversarial check for ExUnit test-manifest source bindings.

  The caller supplies the manifest's module/file declarations and an observed
  module-to-file inventory derived from the actual tracked source. Existing
  files do not establish that they define the declared test module.

  This guard makes no formal-proof claim and does not replace the main
  Proven-Tests executed-result, fixture-obligation or proof-tier contract.
  """

  @spec violations([map()], [map()]) :: [String.t()]
  def violations(manifest, observed) when is_list(manifest) and is_list(observed) do
    definitions = Enum.group_by(observed, & &1.module, & &1.file)

    Enum.flat_map(manifest, fn entry ->
      module = entry["module"]
      declared = entry["file"]

      case Map.get(definitions, module, []) do
        [] ->
          # Missing-module detection is a separate, required contract check.
          []

        [^declared] ->
          []

        [actual] ->
          [
            "#{module}: manifest names #{inspect(declared)}, actual module is in #{inspect(actual)}"
          ]

        files ->
          ["#{module}: module has ambiguous source definitions #{inspect(files)}"]
      end
    end)
  end
end
