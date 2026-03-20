defmodule BeamDcd.Analyzer do
  @moduledoc """
  Main analysis engine that orchestrates the three-phase pipeline:
  Phase 1 — collect exports, Phase 2 — collect references,
  Phase 3 — compute unused functions.
  """

  alias BeamDcd.{ChunkParser, Config, EntrypointDetector, ReferenceCollector, SourceMapper}

  @type mfa_info :: %{
          module: module(),
          function: atom(),
          arity: non_neg_integer(),
          source_file: String.t() | nil
        }

  @type analysis_result :: %{
          unused_functions: [mfa_info()],
          summary: %{
            total_exports_analyzed: non_neg_integer(),
            total_unused: non_neg_integer(),
            modules_analyzed: non_neg_integer(),
            warnings: [String.t()]
          }
        }

  @spec analyze(Config.t()) :: {:ok, analysis_result()}
  def analyze(%Config{} = config) do
    beam_files = discover_beam_files(config)
    project_root = File.cwd!()

    # Phase 1: Collect all exports from project BEAM files
    {project_files, _dep_files} = partition_project_files(beam_files, config)

    all_beam_files = if config.exclude_deps, do: project_files, else: beam_files

    exports_by_module = collect_all_exports(project_files)
    source_map = SourceMapper.build_source_map(project_files)

    # Phase 2: Collect all references from ALL BEAM files (including deps)
    # Deps' exports aren't reported, but their references count as "used"
    {ref_results, warnings} = ReferenceCollector.collect_batch(beam_files)
    all_used = ReferenceCollector.merge_used(ref_results)

    # Phase 3: Compute unused
    unused_functions =
      exports_by_module
      |> Enum.flat_map(fn {module, %{exports: exports, attributes: attributes}} ->
        # Filter entrypoints
        reportable = EntrypointDetector.filter_entrypoints(exports, attributes, config.extra_entrypoints)

        # Filter ignored modules
        reportable =
          if should_ignore_module?(module, config.ignore_modules),
            do: [],
            else: reportable

        # Filter ignored functions
        reportable = Enum.reject(reportable, &ignored_function?(&1, config.ignore_functions))

        # Filter actually used
        reportable
        |> Enum.reject(fn mfa -> MapSet.member?(all_used, mfa) end)
        |> Enum.map(fn {mod, fun, arity} ->
          source = Map.get(source_map, mod)

          relative_source = get_relative_source(source, project_root)

          %{
            module: mod,
            function: fun,
            arity: arity,
            source_file: relative_source
          }
        end)
      end)
      |> Enum.sort_by(fn info -> {info.source_file || "", info.function, info.arity} end)

    modules_analyzed =
      if config.exclude_deps, do: length(project_files), else: length(all_beam_files)

    total_exports =
      exports_by_module
      |> Map.values()
      |> Enum.map(fn %{exports: exports} -> length(exports) end)
      |> Enum.sum()

    result = %{
      unused_functions: unused_functions,
      summary: %{
        total_exports_analyzed: total_exports,
        total_unused: length(unused_functions),
        modules_analyzed: modules_analyzed,
        warnings: warnings
      }
    }

    {:ok, result}
  end

  defp get_relative_source(source, _project_root) when source in [false, nil],
    do: nil

  defp get_relative_source(source, project_root),
    do: SourceMapper.relative_source_path(source, project_root)

  defp discover_beam_files(%Config{beam_paths: beam_paths, include_test: include_test}) do
    base_files =
      beam_paths
      |> Enum.flat_map(fn pattern ->
        Path.wildcard(pattern <> "/*.beam")
      end)

    test_files =
      if include_test do
        Path.wildcard("_build/test/lib/*/ebin/*.beam")
      else
        []
      end

    (base_files ++ test_files)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp partition_project_files(beam_files, %Config{exclude_deps: true}) do
    app_name = Mix.Project.config()[:app] |> to_string()
    project_ebin = "_build/dev/lib/#{app_name}/ebin"

    {project, deps} =
      Enum.split_with(beam_files, fn path ->
        String.contains?(path, project_ebin)
      end)

    {project, deps}
  end

  defp partition_project_files(beam_files, _config) do
    {beam_files, []}
  end

  defp collect_all_exports(beam_files) do
    beam_files
    |> Task.async_stream(
      fn beam_file ->
        case ChunkParser.parse_all(beam_file) do
          {:ok, %{module: module, exports: exports, attributes: attributes}} ->
            {module, %{exports: exports, attributes: attributes}}

          {:error, _} ->
            nil
        end
      end,
      timeout: 30_000,
      ordered: false
    )
    |> Enum.reduce(%{}, fn
      {:ok, {module, data}}, acc -> Map.put(acc, module, data)
      _, acc -> acc
    end)
  end

  defp should_ignore_module?(_module, []), do: false

  defp should_ignore_module?(module, ignore_patterns) do
    module_name = Atom.to_string(module)

    Enum.any?(ignore_patterns, fn
      %Regex{} = regex -> Regex.match?(regex, module_name)
      atom when is_atom(atom) -> module == atom
      _ -> false
    end)
  end

  defp ignored_function?(_mfa, []), do: false

  defp ignored_function?({mod, fun, arity}, ignore_list) do
    Enum.any?(ignore_list, fn
      {^mod, ^fun, ^arity} -> true
      {:_, ^fun, ^arity} -> true
      {^mod, :_, ^arity} -> true
      {^mod, ^fun, :_} -> true
      {:_, :_, ^arity} -> true
      {:_, ^fun, :_} -> true
      {^mod, :_, :_} -> true
      {:_, :_, :_} -> true
      _ -> false
    end)
  end
end
