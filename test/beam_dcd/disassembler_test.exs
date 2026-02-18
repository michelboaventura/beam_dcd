defmodule BeamDcd.DisassemblerTest do
  use ExUnit.Case, async: true

  alias BeamDcd.Disassembler

  describe "extract_references/1" do
    test "extracts external call references from a BEAM file" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, BeamDcd.ChunkParser, references} = Disassembler.extract_references(beam_file)
      assert is_list(references)
      assert length(references) > 0

      # ChunkParser calls :beam_lib.chunks/2
      assert {:beam_lib, :chunks, 2} in references
    end

    test "extracts references from Enum-using modules" do
      # BeamDcd.ChunkParser uses Enum.map
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, _module, references} = Disassembler.extract_references(beam_file)

      # Should find Enum calls
      has_enum_ref = Enum.any?(references, fn {mod, _fun, _ar} -> mod == Enum end)
      assert has_enum_ref
    end

    test "returns module name in result" do
      beam_file = beam_path(BeamDcd)
      assert {:ok, BeamDcd, _references} = Disassembler.extract_references(beam_file)
    end

    test "returns unique references" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, _module, references} = Disassembler.extract_references(beam_file)
      assert references == Enum.uniq(references)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = Disassembler.extract_references("/nonexistent/file.beam")
    end

    test "accepts charlist paths" do
      beam_file = beam_path(BeamDcd.ChunkParser) |> String.to_charlist()
      assert {:ok, _module, references} = Disassembler.extract_references(beam_file)
      assert is_list(references)
    end

    test "all references are valid MFA tuples" do
      beam_file = beam_path(BeamDcd.ChunkParser)
      assert {:ok, _module, references} = Disassembler.extract_references(beam_file)

      for {mod, fun, arity} <- references do
        assert is_atom(mod), "module should be atom, got: #{inspect(mod)}"
        assert is_atom(fun), "function should be atom, got: #{inspect(fun)}"
        assert is_integer(arity) and arity >= 0, "arity should be non-negative integer, got: #{inspect(arity)}"
      end
    end
  end

  defp beam_path(module) do
    :code.which(module) |> to_string()
  end
end
