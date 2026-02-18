defmodule BeamDcd.ReferenceCollector do
  @moduledoc """
  Orchestrates all three analysis layers (import tables, bytecode disassembly,
  abstract code) to compute the complete set of used functions from BEAM files.
  Supports parallel batch processing via `Task.async_stream`.
  """

  alias BeamDcd.{ChunkParser, Disassembler, AbstractAnalyzer}

  @type mfa_tuple :: {module(), atom(), arity()}

  @type analysis_result :: %{
          used_functions: MapSet.t(mfa_tuple()),
          warnings: [String.t()],
          dynamic_dispatch_detected: boolean()
        }

  @spec collect(Path.t()) :: {:ok, analysis_result()} | {:error, term()}
  def collect(beam_file) do
    with {:ok, layer_a} <- ChunkParser.parse_imports(beam_file),
         {:ok, _module, layer_b} <- Disassembler.extract_references(beam_file) do
      # Layer C is optional — works without debug info
      {layer_c, warnings} =
        case AbstractAnalyzer.extract_references(beam_file) do
          {:ok, refs, warns} -> {refs, warns}
          {:error, :no_debug_info} -> {[], []}
        end

      used = MapSet.new(layer_a ++ layer_b ++ layer_c)

      result = %{
        used_functions: used,
        warnings: warnings,
        dynamic_dispatch_detected: Enum.any?(warnings, &String.contains?(&1, "apply"))
      }

      {:ok, result}
    end
  end

  @spec collect_batch([Path.t()]) :: {%{Path.t() => analysis_result()}, [String.t()]}
  def collect_batch(beam_files) do
    results =
      beam_files
      |> Task.async_stream(&{&1, collect(&1)}, timeout: 30_000, ordered: false)
      |> Enum.reduce(%{}, fn
        {:ok, {path, {:ok, data}}}, acc -> Map.put(acc, path, data)
        {:ok, {_path, {:error, _}}}, acc -> acc
        {:exit, _}, acc -> acc
      end)

    all_warnings =
      results
      |> Map.values()
      |> Enum.flat_map(& &1.warnings)
      |> Enum.uniq()

    {results, all_warnings}
  end

  @spec merge_used(map()) :: MapSet.t(mfa_tuple())
  def merge_used(results_map) do
    results_map
    |> Map.values()
    |> Enum.reduce(MapSet.new(), fn result, acc ->
      MapSet.union(acc, result.used_functions)
    end)
  end
end
