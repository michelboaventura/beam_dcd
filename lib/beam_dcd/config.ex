defmodule BeamDcd.Config do
  @moduledoc """
  Configuration loader for BeamDcd. Supports loading from `.beam_unused.exs`
  config files and applying command-line flag overrides.

  Precedence: defaults < config file < CLI flags.
  """

  @type t :: %__MODULE__{
          beam_paths: [String.t()],
          exclude_deps: boolean(),
          include_test: boolean(),
          ignore_modules: [Regex.t() | atom()],
          ignore_functions: [{module(), atom(), arity()}],
          extra_entrypoints: [{module(), atom(), arity()}],
          treat_test_as_caller: boolean(),
          output_format: :text | :json | :github | :sarif,
          severity: :definite | :probable,
          strict: boolean()
        }

  defstruct beam_paths: ["_build/dev/lib/*/ebin"],
            exclude_deps: true,
            include_test: false,
            ignore_modules: [],
            ignore_functions: [],
            extra_entrypoints: [],
            treat_test_as_caller: true,
            output_format: :text,
            severity: :definite,
            strict: false

  @spec load(Path.t() | nil) :: {:ok, t()} | {:error, term()}
  def load(config_path \\ nil) do
    config_file = config_path || ".beam_unused.exs"

    base_config = %__MODULE__{}

    if File.exists?(config_file) do
      try do
        case Code.eval_file(config_file) do
          {config_map, _bindings} when is_map(config_map) ->
            {:ok, merge(base_config, config_map)}

          {config_list, _bindings} when is_list(config_list) ->
            {:ok, merge(base_config, Map.new(config_list))}

          _ ->
            {:error, "Invalid config file format — expected a map or keyword list"}
        end
      rescue
        e -> {:error, "Error loading config file: #{Exception.message(e)}"}
      end
    else
      {:ok, base_config}
    end
  end

  @spec apply_cli_flags(t(), keyword()) :: t()
  def apply_cli_flags(config, flags) do
    Enum.reduce(flags, config, fn
      {:format, value}, acc -> %{acc | output_format: parse_format(value)}
      {:include_deps, true}, acc -> %{acc | exclude_deps: false}
      {:include_test, true}, acc -> %{acc | include_test: true}
      {:strict, true}, acc -> %{acc | strict: true}
      _, acc -> acc
    end)
  end

  defp merge(config, overrides) do
    valid_keys = Map.keys(%__MODULE__{}) -- [:__struct__]

    Enum.reduce(valid_keys, config, fn key, acc ->
      case Map.get(overrides, key) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp parse_format(format) when is_atom(format), do: format

  defp parse_format(format) when is_binary(format) do
    case format do
      "text" -> :text
      "json" -> :json
      "github" -> :github
      "sarif" -> :sarif
      _ -> :text
    end
  end
end
