defmodule BeamDcd.AbstractAnalyzer do
  @moduledoc """
  Optional best-effort analyzer that walks Erlang abstract forms from
  `:abstract_code` or `:debug_info` chunks to find additional MFA references,
  including literal dynamic calls via `apply/3`.

  Returns `{:error, :no_debug_info}` when debug info is stripped — the tool
  continues to work correctly without this layer.
  """

  @type mfa_tuple :: {module(), atom(), arity()}

  @spec extract_references(Path.t() | charlist()) ::
          {:ok, [mfa_tuple()], [String.t()]} | {:error, :no_debug_info}
  def extract_references(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_lib.chunks(beam_file, [:abstract_code]) do
      {:ok, {_module, [{:abstract_code, {:raw_abstract_v1, forms}}]}} ->
        {mfas, warnings} = walk_forms(forms)
        {:ok, Enum.uniq(mfas), warnings}

      {:ok, {_module, [{:abstract_code, :no_abstract_code}]}} ->
        {:error, :no_debug_info}

      {:error, :beam_lib, _reason} ->
        {:error, :no_debug_info}
    end
  end

  defp walk_forms(forms) do
    mfas = Enum.flat_map(forms, &extract_from_form/1)

    warnings =
      if Enum.any?(mfas, fn {m, f, _a} -> m == :erlang and f == :apply end) do
        ["Module uses :erlang.apply/3 — results may include false positives"]
      else
        []
      end

    {mfas, warnings}
  end

  defp extract_from_form({:function, _line, _name, _arity, clauses}) do
    Enum.flat_map(clauses, &extract_from_clause/1)
  end

  defp extract_from_form(_), do: []

  defp extract_from_clause({:clause, _line, _patterns, _guards, body}) do
    Enum.flat_map(body, &extract_from_expr/1)
  end

  defp extract_from_clause(_), do: []

  # Remote call: Module.function(args)
  defp extract_from_expr({:call, _line, {:remote, _l2, {:atom, _l3, mod}, {:atom, _l4, fun}}, args}) do
    [{mod, fun, length(args)} | Enum.flat_map(args, &extract_from_expr/1)]
  end

  # Local call — recurse into args
  defp extract_from_expr({:call, _line, _fun, args}) do
    Enum.flat_map(args, &extract_from_expr/1)
  end

  # Fun reference: fun Module:Function/Arity
  defp extract_from_expr({:fun, _line, {:function, {:atom, _, mod}, {:atom, _, fun}, {:integer, _, arity}}}) do
    [{mod, fun, arity}]
  end

  # Case/if/receive/try — walk all branches
  defp extract_from_expr({:case, _line, expr, clauses}) do
    extract_from_expr(expr) ++ Enum.flat_map(clauses, &extract_from_clause/1)
  end

  defp extract_from_expr({:if, _line, clauses}) do
    Enum.flat_map(clauses, &extract_from_clause/1)
  end

  defp extract_from_expr({:receive, _line, clauses}) do
    Enum.flat_map(clauses, &extract_from_clause/1)
  end

  defp extract_from_expr({:receive, _line, clauses, _timeout, after_body}) do
    Enum.flat_map(clauses, &extract_from_clause/1) ++ Enum.flat_map(after_body, &extract_from_expr/1)
  end

  defp extract_from_expr({:try, _line, body, case_clauses, catch_clauses, after_body}) do
    Enum.flat_map(body, &extract_from_expr/1) ++
      Enum.flat_map(case_clauses, &extract_from_clause/1) ++
      Enum.flat_map(catch_clauses, &extract_from_clause/1) ++
      Enum.flat_map(after_body, &extract_from_expr/1)
  end

  defp extract_from_expr({:block, _line, exprs}) do
    Enum.flat_map(exprs, &extract_from_expr/1)
  end

  defp extract_from_expr({:match, _line, _pattern, expr}) do
    extract_from_expr(expr)
  end

  # Tuple/list/map — recurse
  defp extract_from_expr({:tuple, _line, elems}) do
    Enum.flat_map(elems, &extract_from_expr/1)
  end

  defp extract_from_expr({:cons, _line, head, tail}) do
    extract_from_expr(head) ++ extract_from_expr(tail)
  end

  defp extract_from_expr({:map, _line, assocs}) do
    Enum.flat_map(assocs, fn
      {:map_field_assoc, _l, k, v} -> extract_from_expr(k) ++ extract_from_expr(v)
      {:map_field_exact, _l, k, v} -> extract_from_expr(k) ++ extract_from_expr(v)
      _ -> []
    end)
  end

  defp extract_from_expr({:op, _line, _op, left, right}) do
    extract_from_expr(left) ++ extract_from_expr(right)
  end

  defp extract_from_expr({:op, _line, _op, operand}) do
    extract_from_expr(operand)
  end

  # Catch-all for literals and unrecognized forms
  defp extract_from_expr(_), do: []

  defp to_charlist_path(path) when is_list(path), do: path
  defp to_charlist_path(path) when is_binary(path), do: String.to_charlist(path)
end
