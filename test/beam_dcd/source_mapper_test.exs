defmodule BeamDcd.SourceMapperTest do
  use ExUnit.Case, async: true

  alias BeamDcd.SourceMapper

  describe "get_source_path/1" do
    test "extracts source path from BEAM file" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, source} = SourceMapper.get_source_path(beam_file)
      assert String.ends_with?(source, "chunk_parser.ex")
    end

    test "returns :not_available for non-existent file" do
      assert :not_available = SourceMapper.get_source_path("/nonexistent/file.beam")
    end
  end

  describe "get_compile_info/1" do
    test "extracts compile info from BEAM file" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, info} = SourceMapper.get_compile_info(beam_file)
      assert is_list(info)
      assert Keyword.has_key?(info, :source)
    end

    test "returns error for non-existent file" do
      assert {:error, _} = SourceMapper.get_compile_info("/nonexistent/file.beam")
    end
  end

  describe "format_module_name/1" do
    test "strips Elixir. prefix from Elixir modules" do
      assert SourceMapper.format_module_name(BeamDcd.ChunkParser) == "BeamDcd.ChunkParser"
    end

    test "leaves Erlang module names as-is" do
      assert SourceMapper.format_module_name(:beam_lib) == "beam_lib"
    end

    test "handles top-level Elixir modules" do
      assert SourceMapper.format_module_name(String) == "String"
    end
  end

  describe "build_source_map/1" do
    test "builds map of module to source path" do
      beam_files = [
        beam_path(BeamDcd.ChunkParser),
        beam_path(BeamDcd.Disassembler)
      ]

      source_map = SourceMapper.build_source_map(beam_files)
      assert is_map(source_map)
      assert Map.has_key?(source_map, BeamDcd.ChunkParser)
      assert Map.has_key?(source_map, BeamDcd.Disassembler)
      assert String.ends_with?(source_map[BeamDcd.ChunkParser], "chunk_parser.ex")
    end
  end

  describe "relative_source_path/2" do
    test "makes path relative to project root" do
      assert SourceMapper.relative_source_path("/home/user/project/lib/foo.ex", "/home/user/project") ==
               "lib/foo.ex"
    end

    test "returns full path when not under root" do
      assert SourceMapper.relative_source_path("/other/lib/foo.ex", "/home/user/project") ==
               "/other/lib/foo.ex"
    end
  end

  defp beam_path(module) do
    :code.which(module) |> to_string()
  end
end
