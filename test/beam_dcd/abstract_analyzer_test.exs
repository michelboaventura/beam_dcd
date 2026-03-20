defmodule BeamDcd.AbstractAnalyzerTest do
  use ExUnit.Case, async: true

  alias BeamDcd.AbstractAnalyzer

  describe "extract_references/1" do
    test "extracts remote call references from a BEAM file with debug info" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, references, warnings} = AbstractAnalyzer.extract_references(beam_file)
      assert is_list(references)
      assert is_list(warnings)
      assert references != []

      # ChunkParser calls :beam_lib.chunks/2
      assert {:beam_lib, :chunks, 2} in references
    end

    test "returns unique references" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, references, _warnings} = AbstractAnalyzer.extract_references(beam_file)
      assert references == Enum.uniq(references)
    end

    test "all references are valid MFA tuples" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, references, _warnings} = AbstractAnalyzer.extract_references(beam_file)

      for {mod, fun, arity} <- references do
        assert is_atom(mod)
        assert is_atom(fun)
        assert is_integer(arity) and arity >= 0
      end
    end

    test "returns empty warnings when no dynamic dispatch" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, _references, warnings} = AbstractAnalyzer.extract_references(beam_file)
      assert warnings == []
    end

    test "returns error for non-existent file" do
      assert {:error, :no_debug_info} = AbstractAnalyzer.extract_references("/nonexistent/file.beam")
    end

    test "accepts charlist paths" do
      beam_file = beam_path(BeamDcd.ChunkParser) |> String.to_charlist()
      assert {:ok, references, _warnings} = AbstractAnalyzer.extract_references(beam_file)
      assert is_list(references)
    end
  end

  defp beam_path(module) do
    :code.which(module) |> to_string()
  end
end
