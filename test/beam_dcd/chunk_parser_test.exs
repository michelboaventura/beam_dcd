defmodule BeamDcd.ChunkParserTest do
  use ExUnit.Case, async: true

  alias BeamDcd.ChunkParser

  describe "parse_exports/1" do
    test "extracts exports from a compiled BEAM file" do
      beam_file = get_beam_path(BeamDcd.ChunkParser)
      assert {:ok, exports} = ChunkParser.parse_exports(beam_file)
      assert is_list(exports)

      # ChunkParser exports its public functions
      assert {BeamDcd.ChunkParser, :parse_exports, 1} in exports
      assert {BeamDcd.ChunkParser, :parse_imports, 1} in exports
      assert {BeamDcd.ChunkParser, :parse_attributes, 1} in exports
      assert {BeamDcd.ChunkParser, :parse_all, 1} in exports
    end

    test "includes module_info in exports" do
      beam_file = get_beam_path(BeamDcd.ChunkParser)
      assert {:ok, exports} = ChunkParser.parse_exports(beam_file)
      assert {BeamDcd.ChunkParser, :module_info, 0} in exports
      assert {BeamDcd.ChunkParser, :module_info, 1} in exports
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = ChunkParser.parse_exports("/nonexistent/file.beam")
    end

    test "accepts charlist paths" do
      beam_file = get_beam_path(BeamDcd.ChunkParser) |> String.to_charlist()
      assert {:ok, exports} = ChunkParser.parse_exports(beam_file)
      assert is_list(exports)
    end
  end

  describe "parse_imports/1" do
    test "extracts imports from a compiled BEAM file" do
      beam_file = get_beam_path(BeamDcd.ChunkParser)
      assert {:ok, imports} = ChunkParser.parse_imports(beam_file)
      assert is_list(imports)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = ChunkParser.parse_imports("/nonexistent/file.beam")
    end
  end

  describe "parse_attributes/1" do
    test "extracts attributes from a compiled BEAM file" do
      beam_file = get_beam_path(BeamDcd.ChunkParser)
      assert {:ok, attrs} = ChunkParser.parse_attributes(beam_file)
      assert is_list(attrs)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = ChunkParser.parse_attributes("/nonexistent/file.beam")
    end
  end

  describe "parse_all/1" do
    test "extracts all chunks in a single call" do
      beam_file = get_beam_path(BeamDcd.ChunkParser)
      assert {:ok, result} = ChunkParser.parse_all(beam_file)
      assert is_map(result)
      assert result.module == BeamDcd.ChunkParser
      assert is_list(result.exports)
      assert is_list(result.imports)
      assert is_list(result.attributes)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = ChunkParser.parse_all("/nonexistent/file.beam")
    end
  end

  defp get_beam_path(module) do
    module.module_info(:compile)
    |> Keyword.get(:source)
    |> Path.rootname()
    |> then(fn _source ->
      :code.which(module) |> to_string()
    end)
  end
end
