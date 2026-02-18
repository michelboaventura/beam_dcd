defmodule BeamDcd.ChunkParser do
  @moduledoc """
  Parses BEAM file chunks using `:beam_lib` to extract export tables,
  import tables, and module attributes as `{module, function, arity}` tuples.
  """

  @type mfa_tuple :: {module(), atom(), arity()}

  @spec parse_exports(Path.t() | charlist()) :: {:ok, [mfa_tuple()]} | {:error, term()}
  def parse_exports(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:exports]) do
      {:ok, {module, [{:exports, exports}]}} ->
        mfas = Enum.map(exports, fn {fun, arity} -> {module, fun, arity} end)
        {:ok, mfas}

      {:error, :beam_lib, reason} ->
        {:error, reason}
    end
  end

  @spec parse_imports(Path.t() | charlist()) :: {:ok, [mfa_tuple()]} | {:error, term()}
  def parse_imports(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:imports]) do
      {:ok, {_module, [{:imports, imports}]}} ->
        {:ok, imports}

      {:error, :beam_lib, reason} ->
        {:error, reason}
    end
  end

  @spec parse_attributes(Path.t() | charlist()) :: {:ok, keyword()} | {:error, term()}
  def parse_attributes(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:attributes]) do
      {:ok, {_module, [{:attributes, attrs}]}} ->
        {:ok, attrs}

      {:error, :beam_lib, reason} ->
        {:error, reason}
    end
  end

  @spec parse_all(Path.t() | charlist()) ::
          {:ok, %{module: module(), exports: [mfa_tuple()], imports: [mfa_tuple()], attributes: keyword()}}
          | {:error, term()}
  def parse_all(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:exports, :imports, :attributes]) do
      {:ok, {module, chunks}} ->
        exports =
          chunks
          |> Keyword.get(:exports, [])
          |> Enum.map(fn {fun, arity} -> {module, fun, arity} end)

        imports = Keyword.get(chunks, :imports, [])
        attributes = Keyword.get(chunks, :attributes, [])

        {:ok, %{module: module, exports: exports, imports: imports, attributes: attributes}}

      {:error, :beam_lib, reason} ->
        {:error, reason}
    end
  end

  defp to_charlist_path(path) when is_list(path), do: path
  defp to_charlist_path(path) when is_binary(path), do: String.to_charlist(path)
end
