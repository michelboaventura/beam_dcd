defmodule BeamDcd.CLI do
  @moduledoc """
  Escript CLI entrypoint for standalone BEAM file analysis.
  Can analyze any collection of BEAM files without requiring a Mix project.

      beam_dcd /path/to/ebin [/path/to/other/ebin ...]  --format text
      beam_dcd --config beam_unused.config               --format json
  """

  alias BeamDcd.{Analyzer, Config, Formatter}

  @switches [
    format: :string,
    strict: :boolean,
    config: :string,
    help: :boolean
  ]

  @aliases [
    f: :format,
    c: :config,
    h: :help
  ]

  def main(args) do
    {opts, paths, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if Keyword.get(opts, :help, false) or (paths == [] and not Keyword.has_key?(opts, :config)) do
      print_usage()
    else
      run(opts, paths)
    end
  end

  defp run(opts, paths) do
    config_path = Keyword.get(opts, :config)

    config =
      case Config.load(config_path) do
        {:ok, config} ->
          config

        {:error, reason} ->
          IO.puts(:stderr, "Error loading config: #{reason}")
          %Config{}
      end

    # Override beam_paths with positional arguments if provided
    config =
      if paths != [] do
        %{config | beam_paths: paths, exclude_deps: false}
      else
        config
      end

    config = Config.apply_cli_flags(config, opts)

    {:ok, result} = Analyzer.analyze(config)
    output = Formatter.format(result, config.output_format)
    IO.puts(output)

    if Keyword.get(opts, :strict, false) and result.summary.total_unused > 0 do
      System.halt(1)
    end
  end

  defp print_usage do
    IO.puts("""
    beam_dcd - BEAM Dead Code Detector

    Usage:
      beam_dcd [paths...] [options]

    Arguments:
      paths          Directories containing .beam files to analyze

    Options:
      -f, --format   Output format: text (default), json, github, sarif
      -c, --config   Path to config file
      --strict       Exit with code 1 if unused functions found
      -h, --help     Show this help message

    Examples:
      beam_dcd _build/dev/lib/my_app/ebin
      beam_dcd /path/to/ebin --format json
      beam_dcd --config .beam_unused.exs --strict
    """)
  end
end
