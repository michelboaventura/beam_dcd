defmodule BeamDcd.Disassembler do
  @moduledoc """
  Disassembles BEAM bytecode using `:beam_disasm.file/1` and extracts all
  MFA references from call-related opcodes including external calls,
  tail calls, fun captures, and BIF calls.
  """

  @type mfa_tuple :: {module(), atom(), arity()}

  @spec extract_references(Path.t() | charlist()) :: {:ok, module(), [mfa_tuple()]} | {:error, term()}
  def extract_references(beam_file) do
    beam_file = to_charlist_path(beam_file)

    case :beam_disasm.file(beam_file) do
      {:beam_file, module, _exports, _attrs, _compile_info, functions} ->
        references =
          functions
          |> Enum.flat_map(&scan_function/1)
          |> Enum.uniq()

        {:ok, module, references}

      {:beam_file, module, _exports, _attrs, functions} ->
        references =
          functions
          |> Enum.flat_map(&scan_function/1)
          |> Enum.uniq()

        {:ok, module, references}

      {:error, :beam_lib, reason} ->
        {:error, reason}

      error ->
        {:error, error}
    end
  end

  defp scan_function({:function, _name, _arity, _entry, instructions}) do
    Enum.flat_map(instructions, &extract_mfa/1)
  end

  defp scan_function(_), do: []

  # External calls
  defp extract_mfa({:call_ext, _arity, {:extfunc, mod, fun, ar}}), do: [{mod, fun, ar}]
  defp extract_mfa({:call_ext_only, _arity, {:extfunc, mod, fun, ar}}), do: [{mod, fun, ar}]
  defp extract_mfa({:call_ext_last, _arity, {:extfunc, mod, fun, ar}, _dealloc}), do: [{mod, fun, ar}]

  # Fun captures
  defp extract_mfa({:make_fun2, {mod, fun, ar}, _idx, _old_uniq, _num_free}), do: [{mod, fun, ar}]
  defp extract_mfa({:make_fun3, {mod, fun, ar}, _idx, _uniq, _env}), do: [{mod, fun, ar}]

  # BIF calls — various forms
  defp extract_mfa({:bif, name, _fail, args, _dest}) when is_atom(name), do: [{:erlang, name, length(args)}]
  defp extract_mfa({:bif0, {:extfunc, mod, fun, ar}, _dest}), do: [{mod, fun, ar}]
  defp extract_mfa({:bif1, _fail, {:extfunc, mod, fun, ar}, _arg, _dest}), do: [{mod, fun, ar}]
  defp extract_mfa({:bif2, _fail, {:extfunc, mod, fun, ar}, _arg1, _arg2, _dest}), do: [{mod, fun, ar}]
  defp extract_mfa({:gc_bif, name, _fail, _live, args, _dest}) when is_atom(name), do: [{:erlang, name, length(args)}]

  # Catch-all
  defp extract_mfa(_), do: []

  defp to_charlist_path(path) when is_list(path), do: path
  defp to_charlist_path(path) when is_binary(path), do: String.to_charlist(path)
end
