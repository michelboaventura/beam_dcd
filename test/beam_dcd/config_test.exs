defmodule BeamDcd.ConfigTest do
  use ExUnit.Case, async: true

  alias BeamDcd.Config

  describe "load/0" do
    test "returns default config when no config file exists" do
      assert {:ok, config} = Config.load("/nonexistent/.beam_unused.exs")
      assert config.beam_paths == ["_build/dev/lib/*/ebin"]
      assert config.exclude_deps == true
      assert config.include_test == false
      assert config.ignore_modules == []
      assert config.ignore_functions == []
      assert config.extra_entrypoints == []
      assert config.treat_test_as_caller == true
      assert config.output_format == :text
      assert config.severity == :definite
      assert config.strict == false
    end
  end

  describe "load/1 with config file" do
    setup do
      config_path = Path.join(System.tmp_dir!(), "test_beam_unused_#{System.unique_integer([:positive])}.exs")

      on_exit(fn ->
        File.rm(config_path)
      end)

      {:ok, config_path: config_path}
    end

    test "loads map config from file", %{config_path: config_path} do
      File.write!(config_path, """
      %{
        exclude_deps: false,
        output_format: :json,
        beam_paths: ["_build/prod/lib/*/ebin"]
      }
      """)

      assert {:ok, config} = Config.load(config_path)
      assert config.exclude_deps == false
      assert config.output_format == :json
      assert config.beam_paths == ["_build/prod/lib/*/ebin"]
      # Defaults preserved
      assert config.treat_test_as_caller == true
    end

    test "loads keyword list config from file", %{config_path: config_path} do
      File.write!(config_path, """
      [
        exclude_deps: false,
        output_format: :json
      ]
      """)

      assert {:ok, config} = Config.load(config_path)
      assert config.exclude_deps == false
      assert config.output_format == :json
    end

    test "returns error for invalid config file", %{config_path: config_path} do
      File.write!(config_path, """
      "just a string"
      """)

      assert {:error, msg} = Config.load(config_path)
      assert is_binary(msg)
    end

    test "returns error for syntax error in config", %{config_path: config_path} do
      File.write!(config_path, """
      %{broken: [
      """)

      assert {:error, msg} = Config.load(config_path)
      assert is_binary(msg)
    end
  end

  describe "apply_cli_flags/2" do
    test "applies format flag" do
      config = %Config{}
      result = Config.apply_cli_flags(config, format: "json")
      assert result.output_format == :json
    end

    test "applies include_deps flag" do
      config = %Config{}
      result = Config.apply_cli_flags(config, include_deps: true)
      assert result.exclude_deps == false
    end

    test "applies strict flag" do
      config = %Config{}
      result = Config.apply_cli_flags(config, strict: true)
      assert result.strict == true
    end

    test "applies multiple flags" do
      config = %Config{}
      result = Config.apply_cli_flags(config, format: "github", strict: true, include_deps: true)
      assert result.output_format == :github
      assert result.strict == true
      assert result.exclude_deps == false
    end

    test "ignores unknown flags" do
      config = %Config{}
      result = Config.apply_cli_flags(config, unknown: true)
      assert result == config
    end
  end
end
