defmodule BeamDcd.IntegrationTest do
  use ExUnit.Case

  alias BeamDcd.{Analyzer, ChunkParser, Config, Disassembler, EntrypointDetector, Formatter, ReferenceCollector}

  @fixture_ebin "_build/test/lib/beam_dcd/ebin"

  describe "full analysis pipeline" do
    test "detects unused functions in fixture modules" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      # TestFixtures.UsedFunctions.public_unused/0 should be detected
      assert {TestFixtures.UsedFunctions, :public_unused, 0} in unused_names

      # TestFixtures.NoExternalCallers functions should be detected
      assert {TestFixtures.NoExternalCallers, :orphan_a, 0} in unused_names
      assert {TestFixtures.NoExternalCallers, :orphan_b, 0} in unused_names
      assert {TestFixtures.NoExternalCallers, :orphan_c, 0} in unused_names
    end

    test "does not report used functions" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      # public_used is called by caller/0 and CrossModuleCaller
      refute {TestFixtures.UsedFunctions, :public_used, 0} in unused_names

      # caller/0 calls public_used, so it's referenced within the module
      # But caller itself is never called externally, so it could be unused
    end

    test "does not report GenServer behaviour callbacks" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      # GenServer callbacks should NOT be reported
      refute {TestFixtures.GenServerImpl, :init, 1} in unused_names
      refute {TestFixtures.GenServerImpl, :handle_call, 3} in unused_names
      refute {TestFixtures.GenServerImpl, :handle_cast, 2} in unused_names

      # But unused_public should be reported
      assert {TestFixtures.GenServerImpl, :unused_public, 0} in unused_names
    end

    test "does not report compiler-generated functions" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)

      for info <- result.unused_functions do
        refute info.function == :module_info
        refute info.function == :__info__
        refute String.starts_with?(to_string(info.function), "MACRO-")
      end
    end

    test "does not report __struct__ functions" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      refute {TestFixtures.StructModule, :__struct__, 0} in unused_names
      refute {TestFixtures.StructModule, :__struct__, 1} in unused_names
    end

    test "ignore_modules config works" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false,
        ignore_modules: [TestFixtures.NoExternalCallers]
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_modules = for info <- result.unused_functions, do: info.module

      refute TestFixtures.NoExternalCallers in unused_modules
    end

    test "ignore_functions config works" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false,
        ignore_functions: [{TestFixtures.UsedFunctions, :public_unused, 0}]
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      refute {TestFixtures.UsedFunctions, :public_unused, 0} in unused_names
    end

    test "ignore_functions with :_ wildcard filters across all modules" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false,
        ignore_functions: [{:_, :orphan_a, 0}]
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      refute {TestFixtures.NoExternalCallers, :orphan_a, 0} in unused_names
      # Other functions should still be reported
      assert {TestFixtures.NoExternalCallers, :orphan_b, 0} in unused_names
    end

    test "ignore_functions with :_ wildcard on arity" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false,
        ignore_functions: [{TestFixtures.NoExternalCallers, :_, :_}]
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_modules = for info <- result.unused_functions, do: info.module

      refute TestFixtures.NoExternalCallers in unused_modules
    end

    test "extra_entrypoints config works" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false,
        extra_entrypoints: [{TestFixtures.NoExternalCallers, :orphan_a, 0}]
      }

      assert {:ok, result} = Analyzer.analyze(config)
      unused_names = for info <- result.unused_functions, do: {info.module, info.function, info.arity}

      refute {TestFixtures.NoExternalCallers, :orphan_a, 0} in unused_names
      # Other orphans should still be reported
      assert {TestFixtures.NoExternalCallers, :orphan_b, 0} in unused_names
    end
  end

  describe "output formatting" do
    test "text output includes module and function names" do
      config = %Config{beam_paths: [@fixture_ebin], exclude_deps: false}
      {:ok, result} = Analyzer.analyze(config)
      output = Formatter.format(result, :text)

      assert output =~ "Unused Public Functions"
      assert is_binary(output)
    end

    test "json output is valid JSON with expected structure" do
      config = %Config{beam_paths: [@fixture_ebin], exclude_deps: false}
      {:ok, result} = Analyzer.analyze(config)
      output = Formatter.format(result, :json)

      assert {:ok, decoded} = JSON.decode(output)
      assert is_list(decoded["unused_functions"])
      assert is_map(decoded["summary"])
    end

    test "github output produces annotation format" do
      config = %Config{beam_paths: [@fixture_ebin], exclude_deps: false}
      {:ok, result} = Analyzer.analyze(config)
      output = Formatter.format(result, :github)

      if result.summary.total_unused > 0 do
        assert output =~ "::warning"
      end
    end

    test "sarif output is valid SARIF JSON" do
      config = %Config{beam_paths: [@fixture_ebin], exclude_deps: false}
      {:ok, result} = Analyzer.analyze(config)
      output = Formatter.format(result, :sarif)

      assert {:ok, decoded} = JSON.decode(output)
      assert decoded["version"] == "2.1.0"
    end
  end

  describe "chunk parser on fixtures" do
    test "parses exports from fixture module" do
      beam_file = beam_path(TestFixtures.UsedFunctions)
      assert {:ok, exports} = ChunkParser.parse_exports(beam_file)

      fun_names = for {_, f, a} <- exports, do: {f, a}
      assert {:public_used, 0} in fun_names
      assert {:public_unused, 0} in fun_names
      assert {:caller, 0} in fun_names
    end

    test "parses GenServer behaviour attributes" do
      beam_file = beam_path(TestFixtures.GenServerImpl)
      assert {:ok, attrs} = ChunkParser.parse_attributes(beam_file)

      behaviours = EntrypointDetector.detect_behaviours(attrs)
      assert GenServer in behaviours
    end
  end

  describe "disassembler on fixtures" do
    test "detects cross-module calls" do
      beam_file = beam_path(TestFixtures.CrossModuleCaller)
      assert {:ok, _module, refs} = Disassembler.extract_references(beam_file)

      assert {TestFixtures.UsedFunctions, :public_used, 0} in refs
    end

    test "detects external fun captures" do
      # Within the same module, fun captures may be compiled as local calls.
      # Test cross-module fun capture by checking Enum.map reference
      beam_file = beam_path(TestFixtures.FunCapture)
      assert {:ok, _module, refs} = Disassembler.extract_references(beam_file)

      assert {Enum, :map, 2} in refs
    end
  end

  describe "reference collector on fixtures" do
    test "collects references from all layers" do
      beam_file = beam_path(TestFixtures.CrossModuleCaller)
      assert {:ok, result} = ReferenceCollector.collect(beam_file)

      assert MapSet.member?(result.used_functions, {TestFixtures.UsedFunctions, :public_used, 0})
    end

    test "batch collection processes multiple files" do
      files = [
        beam_path(TestFixtures.UsedFunctions),
        beam_path(TestFixtures.CrossModuleCaller),
        beam_path(TestFixtures.GenServerImpl)
      ]

      {results, _warnings} = ReferenceCollector.collect_batch(files)
      assert map_size(results) == 3
    end
  end

  describe "self-analysis" do
    test "the tool can analyze itself without errors" do
      config = %Config{
        beam_paths: [@fixture_ebin],
        exclude_deps: false
      }

      assert {:ok, result} = Analyzer.analyze(config)
      assert is_list(result.unused_functions)
      assert result.summary.modules_analyzed > 0
    end
  end

  defp beam_path(module) do
    :code.which(module) |> to_string()
  end
end
