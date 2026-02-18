defmodule BeamDcd.AnalyzerTest do
  use ExUnit.Case

  alias BeamDcd.{Analyzer, Config}

  describe "analyze/1" do
    test "analyzes the project's own BEAM files" do
      config = %Config{
        beam_paths: ["_build/test/lib/beam_dcd/ebin"],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      assert is_list(result.unused_functions)
      assert is_map(result.summary)
      assert result.summary.modules_analyzed > 0
      assert result.summary.total_exports_analyzed > 0
    end

    test "returns valid mfa_info structs for unused functions" do
      config = %Config{
        beam_paths: ["_build/test/lib/beam_dcd/ebin"],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)

      for info <- result.unused_functions do
        assert is_atom(info.module)
        assert is_atom(info.function)
        assert is_integer(info.arity) and info.arity >= 0
      end
    end

    test "does not report compiler-generated functions" do
      config = %Config{
        beam_paths: ["_build/test/lib/beam_dcd/ebin"],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)

      for info <- result.unused_functions do
        refute info.function == :module_info
        refute info.function == :__info__
      end
    end

    test "returns summary with warnings list" do
      config = %Config{
        beam_paths: ["_build/test/lib/beam_dcd/ebin"],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      assert is_list(result.summary.warnings)
    end

    test "handles empty beam_paths" do
      config = %Config{
        beam_paths: ["/nonexistent/path"],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      assert result.unused_functions == []
      assert result.summary.modules_analyzed == 0
    end

    test "ignore_modules filters out specified modules" do
      config = %Config{
        beam_paths: ["_build/test/lib/beam_dcd/ebin"],
        exclude_deps: false,
        ignore_modules: [BeamDcd.ChunkParser]
      }

      assert {:ok, result} = Analyzer.analyze(config)

      refute Enum.any?(result.unused_functions, fn info ->
        info.module == BeamDcd.ChunkParser
      end)
    end

    test "ignore_modules supports regex patterns" do
      config = %Config{
        beam_paths: ["_build/test/lib/beam_dcd/ebin"],
        exclude_deps: false,
        ignore_modules: [~r/ChunkParser/]
      }

      assert {:ok, result} = Analyzer.analyze(config)

      refute Enum.any?(result.unused_functions, fn info ->
        info.module == BeamDcd.ChunkParser
      end)
    end
  end
end
