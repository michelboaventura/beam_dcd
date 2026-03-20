defmodule Mix.Tasks.UnusedFunctionsTest do
  use ExUnit.Case

  alias Mix.Tasks.UnusedFunctions

  describe "run/1" do
    test "runs with default options" do
      # Capture output from the mix task
      output = capture_mix_output(fn -> UnusedFunctions.run([]) end)
      assert output =~ "Unused Public Functions" or output =~ "No unused public functions"
    end

    test "runs with --format json" do
      output = capture_mix_output(fn -> UnusedFunctions.run(["--format", "json"]) end)
      assert {:ok, _} = JSON.decode(output)
    end

    test "runs with --format github" do
      output = capture_mix_output(fn -> UnusedFunctions.run(["--format", "github"]) end)
      # GitHub format is either empty or ::warning lines
      assert output == "" or output =~ "::warning"
    end

    test "runs with --include-deps" do
      output = capture_mix_output(fn -> UnusedFunctions.run(["--include-deps"]) end)
      assert is_binary(output)
    end
  end

  defp capture_mix_output(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end
