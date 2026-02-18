defmodule BeamDcd.ReferenceCollectorTest do
  use ExUnit.Case, async: true

  alias BeamDcd.ReferenceCollector

  describe "collect/1" do
    test "collects references from all three layers" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, result} = ReferenceCollector.collect(beam_file)
      assert %MapSet{} = result.used_functions
      assert MapSet.size(result.used_functions) > 0
      assert is_list(result.warnings)
      assert is_boolean(result.dynamic_dispatch_detected)
    end

    test "includes import table references" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, result} = ReferenceCollector.collect(beam_file)
      # :beam_lib.chunks/2 should be in the used set
      assert MapSet.member?(result.used_functions, {:beam_lib, :chunks, 2})
    end

    test "returns error for invalid file" do
      assert {:error, _reason} = ReferenceCollector.collect("/nonexistent/file.beam")
    end
  end

  describe "collect_batch/1" do
    test "processes multiple BEAM files in parallel" do
      beam_files = [
        beam_path(BeamDcd.ChunkParser),
        beam_path(BeamDcd.Disassembler),
        beam_path(BeamDcd.AbstractAnalyzer)
      ]

      {results, warnings} = ReferenceCollector.collect_batch(beam_files)
      assert is_map(results)
      assert map_size(results) == 3
      assert is_list(warnings)
    end

    test "skips files that fail" do
      beam_files = [
        beam_path(BeamDcd.ChunkParser),
        "/nonexistent/file.beam"
      ]

      {results, _warnings} = ReferenceCollector.collect_batch(beam_files)
      assert map_size(results) == 1
    end
  end

  describe "merge_used/1" do
    test "merges used functions from multiple results" do
      beam_files = [
        beam_path(BeamDcd.ChunkParser),
        beam_path(BeamDcd.Disassembler)
      ]

      {results, _warnings} = ReferenceCollector.collect_batch(beam_files)
      merged = ReferenceCollector.merge_used(results)
      assert %MapSet{} = merged
      assert MapSet.size(merged) > 0
    end
  end

  defp beam_path(module) do
    :code.which(module) |> to_string()
  end
end
