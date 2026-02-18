defmodule BeamDcd.SourceMapper do
  @moduledoc """
  Maps BEAM modules back to source file paths using the `:compile` chunk's
  `source` attribute. Falls back to module name display when source paths
  are unavailable.
  """

  @spec get_source_path(Path.t() | charlist()) :: {:ok, String.t()} | :not_available
  def get_source_path(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:compile_info]) do
      {:ok, {_module, [{:compile_info, info}]}} ->
        case Keyword.get(info, :source) do
          nil -> :not_available
          source -> {:ok, to_string(source)}
        end

      _ ->
        :not_available
    end
  end

  @spec get_compile_info(Path.t() | charlist()) :: {:ok, keyword()} | {:error, term()}
  def get_compile_info(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:compile_info]) do
      {:ok, {_module, [{:compile_info, info}]}} ->
        {:ok, info}

      {:error, :beam_lib, reason} ->
        {:error, reason}
    end
  end

  @spec format_module_name(module()) :: String.t()
  def format_module_name(module) when is_atom(module) do
    name = Atom.to_string(module)

    case name do
      "Elixir." <> rest -> rest
      other -> other
    end
  end

  @spec build_source_map([Path.t()]) :: %{module() => String.t()}
  def build_source_map(beam_files) do
    beam_files
    |> Task.async_stream(
      fn beam_file ->
        beam_file = to_charlist_path(beam_file)

        case :beam_lib.chunks(beam_file, [:compile_info]) do
          {:ok, {module, [{:compile_info, info}]}} ->
            source = Keyword.get(info, :source)
            if source, do: {module, to_string(source)}, else: nil

          _ ->
            nil
        end
      end, timeout: 10_000, ordered: false)
    |> Enum.reduce(%{}, fn
      {:ok, {module, source}}, acc -> Map.put(acc, module, source)
      _, acc -> acc
    end)
  end

  @spec relative_source_path(String.t(), String.t()) :: String.t()
  def relative_source_path(source_path, project_root) do
    Path.relative_to(source_path, project_root)
  end

  defp to_charlist_path(path) when is_list(path), do: path
  defp to_charlist_path(path) when is_binary(path), do: String.to_charlist(path)
end
