defmodule BeamDcd.FormatterTest do
  use ExUnit.Case, async: true

  alias BeamDcd.Formatter

  @sample_result %{
    unused_functions: [
      %{module: :"Elixir.MyApp.Accounts", function: :get_user_by_token, arity: 1, source_file: "lib/my_app/accounts.ex"},
      %{module: :"Elixir.MyApp.Accounts", function: :deprecated_auth_check, arity: 2, source_file: "lib/my_app/accounts.ex"},
      %{module: :"Elixir.MyApp.Helpers", function: :format_legacy_date, arity: 1, source_file: "lib/my_app/helpers.ex"}
    ],
    summary: %{
      total_exports_analyzed: 347,
      total_unused: 3,
      modules_analyzed: 42,
      warnings: []
    }
  }

  @empty_result %{
    unused_functions: [],
    summary: %{
      total_exports_analyzed: 100,
      total_unused: 0,
      modules_analyzed: 10,
      warnings: []
    }
  }

  describe "format/2 with :text" do
    test "formats unused functions as tree" do
      output = Formatter.format(@sample_result, :text)
      assert output =~ "== Unused Public Functions =="
      assert output =~ "MyApp.Accounts"
      assert output =~ "get_user_by_token/1"
      assert output =~ "deprecated_auth_check/2"
      assert output =~ "MyApp.Helpers"
      assert output =~ "format_legacy_date/1"
      assert output =~ "Found 3 unused public functions across 2 modules."
    end

    test "formats empty results" do
      output = Formatter.format(@empty_result, :text)
      assert output =~ "No unused public functions found."
      assert output =~ "Analyzed 10 modules"
    end

    test "includes warnings when present" do
      result = put_in(@sample_result.summary.warnings, ["Module uses :erlang.apply/3"])
      output = Formatter.format(result, :text)
      assert output =~ "Warnings:"
      assert output =~ "Module uses :erlang.apply/3"
    end
  end

  describe "format/2 with :json" do
    test "produces valid JSON" do
      output = Formatter.format(@sample_result, :json)
      assert {:ok, decoded} = Jason.decode(output)
      assert is_list(decoded["unused_functions"])
      assert length(decoded["unused_functions"]) == 3
      assert decoded["summary"]["total_unused"] == 3
    end

    test "includes all fields" do
      output = Formatter.format(@sample_result, :json)
      {:ok, decoded} = Jason.decode(output)
      first = List.first(decoded["unused_functions"])
      assert Map.has_key?(first, "module")
      assert Map.has_key?(first, "function")
      assert Map.has_key?(first, "arity")
      assert Map.has_key?(first, "source_file")
    end
  end

  describe "format/2 with :github" do
    test "produces GitHub Actions annotation format" do
      output = Formatter.format(@sample_result, :github)
      lines = String.split(output, "\n")
      assert length(lines) == 3

      assert Enum.all?(lines, fn line ->
        String.starts_with?(line, "::warning file=")
      end)
    end

    test "includes function details" do
      output = Formatter.format(@sample_result, :github)
      assert output =~ "get_user_by_token/1"
      assert output =~ "lib/my_app/accounts.ex"
    end
  end

  describe "format/2 with :sarif" do
    test "produces valid SARIF JSON" do
      output = Formatter.format(@sample_result, :sarif)
      assert {:ok, decoded} = Jason.decode(output)
      assert decoded["version"] == "2.1.0"
      assert length(decoded["runs"]) == 1

      run = List.first(decoded["runs"])
      assert run["tool"]["driver"]["name"] == "BeamDcd"
      assert length(run["results"]) == 3
    end
  end
end
