defmodule BeamDcd.Formatter do
  @moduledoc """
  Output formatters for analysis results. Supports text, JSON, GitHub Actions
  annotations, and SARIF formats.
  """

  alias BeamDcd.SourceMapper

  @spec format(map(), :text | :json | :github | :sarif) :: String.t()
  def format(result, format \\ :text)

  def format(result, :text), do: format_text(result)
  def format(result, :json), do: format_json(result)
  def format(result, :github), do: format_github(result)
  def format(result, :sarif), do: format_sarif(result)

  # -- Text format --

  defp format_text(%{unused_functions: [], summary: summary}) do
    """
    == Unused Public Functions ==

    No unused public functions found.

    Analyzed #{summary.modules_analyzed} modules, #{summary.total_exports_analyzed} exports.
    #{format_warnings_text(summary.warnings)}\
    """
    |> String.trim_trailing()
  end

  defp format_text(%{unused_functions: unused, summary: summary}) do
    grouped =
      unused
      |> Enum.group_by(fn info ->
        {info.source_file || SourceMapper.format_module_name(info.module), info.module}
      end)
      |> Enum.sort_by(fn {{source, _mod}, _} -> source end)

    module_sections =
      grouped
      |> Enum.map(fn {{source, module}, functions} ->
        header = "#{source} (#{SourceMapper.format_module_name(module)})"
        funcs = format_function_tree(functions)
        "#{header}\n#{funcs}"
      end)
      |> Enum.join("\n\n")

    modules_count = length(grouped)

    """
    == Unused Public Functions ==

    #{module_sections}

    Found #{summary.total_unused} unused public function#{plural(summary.total_unused)} across #{modules_count} module#{plural(modules_count)}.
    #{format_warnings_text(summary.warnings)}\
    """
    |> String.trim_trailing()
  end

  defp format_function_tree(functions) do
    functions
    |> Enum.sort_by(fn info -> {info.function, info.arity} end)
    |> Enum.with_index()
    |> Enum.map(fn {info, idx} ->
      connector = if idx == length(functions) - 1, do: "└──", else: "├──"
      "  #{connector} #{info.function}/#{info.arity}"
    end)
    |> Enum.join("\n")
  end

  defp format_warnings_text([]), do: ""

  defp format_warnings_text(warnings) do
    warning_lines = Enum.map(warnings, fn w -> "  ⚠ #{w}" end) |> Enum.join("\n")
    "\n\nWarnings:\n#{warning_lines}"
  end

  # -- JSON format --

  defp format_json(%{unused_functions: unused, summary: summary}) do
    data = %{
      "unused_functions" =>
        Enum.map(unused, fn info ->
          %{
            "module" => Atom.to_string(info.module),
            "function" => Atom.to_string(info.function),
            "arity" => info.arity,
            "source_file" => info.source_file
          }
        end),
      "summary" => %{
        "total_exports_analyzed" => summary.total_exports_analyzed,
        "total_unused" => summary.total_unused,
        "modules_analyzed" => summary.modules_analyzed
      }
    }

    Jason.encode!(data, pretty: true)
  end

  # -- GitHub Actions format --

  defp format_github(%{unused_functions: unused}) do
    unused
    |> Enum.map(fn info ->
      file = info.source_file || "unknown"

      "::warning file=#{file}::Unused public function: #{SourceMapper.format_module_name(info.module)}.#{info.function}/#{info.arity}"
    end)
    |> Enum.join("\n")
  end

  # -- SARIF format --

  defp format_sarif(%{unused_functions: unused, summary: _summary}) do
    sarif = %{
      "$schema" => "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
      "version" => "2.1.0",
      "runs" => [
        %{
          "tool" => %{
            "driver" => %{
              "name" => "BeamDcd",
              "version" => "0.1.0",
              "informationUri" => "https://github.com/beam-dcd/beam_dcd",
              "rules" => [
                %{
                  "id" => "BEAM001",
                  "name" => "UnusedPublicFunction",
                  "shortDescription" => %{"text" => "Unused public function detected"},
                  "defaultConfiguration" => %{"level" => "warning"}
                }
              ]
            }
          },
          "results" =>
            Enum.map(unused, fn info ->
              %{
                "ruleId" => "BEAM001",
                "level" => "warning",
                "message" => %{
                  "text" =>
                    "Unused public function: #{SourceMapper.format_module_name(info.module)}.#{info.function}/#{info.arity}"
                },
                "locations" => [
                  %{
                    "physicalLocation" => %{
                      "artifactLocation" => %{
                        "uri" => info.source_file || "unknown"
                      }
                    }
                  }
                ]
              }
            end)
        }
      ]
    }

    Jason.encode!(sarif, pretty: true)
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
