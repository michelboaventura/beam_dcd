defmodule Mix.Tasks.UnusedFunctions do
  @shortdoc "Detect unused public functions in BEAM files"

  @moduledoc """
  Analyzes compiled BEAM files to detect unused public functions.

      mix unused_functions                    # Run with defaults
      mix unused_functions --format json      # JSON output
      mix unused_functions --include-deps     # Include dependencies in analysis
      mix unused_functions --strict           # Exit with non-zero code if unused found
      mix unused_functions --config path      # Custom config file path
      mix unused_functions --include-test     # Include test BEAM files

  The task will compile the project first if needed, then run the analysis
  pipeline and output results.

  ## Options

    * `--format` - Output format: text (default), json, github, sarif
    * `--include-deps` - Include dependencies in analysis (they're excluded by default)
    * `--include-test` - Include test BEAM files in analysis
    * `--strict` - Exit with code 1 if unused functions are found (for CI)
    * `--config` - Path to custom config file (default: .beam_unused.exs)

  """

  use Mix.Task

  alias BeamDcd.{Analyzer, Config, Formatter}

  @switches [
    format: :string,
    include_deps: :boolean,
    include_test: :boolean,
    strict: :boolean,
    config: :string
  ]

  @aliases [
    f: :format,
    c: :config
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    # Ensure the project is compiled
    Mix.Task.run("compile", ["--no-protocol-consolidation"])

    # Load config
    config_path = Keyword.get(opts, :config)

    config =
      case Config.load(config_path) do
        {:ok, config} ->
          Config.apply_cli_flags(config, opts)

        {:error, reason} ->
          Mix.shell().error("Error loading config: #{reason}")
          %Config{}
      end

    # Run analysis
    {:ok, result} = Analyzer.analyze(config)
    output = Formatter.format(result, config.output_format)
    Mix.shell().info(output)

    if config.strict and result.summary.total_unused > 0 do
      Mix.raise("Found #{result.summary.total_unused} unused public function(s)")
    end
  end
end
