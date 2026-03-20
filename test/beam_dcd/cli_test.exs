defmodule BeamDcd.CLITest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  describe "main/1 with --help" do
    test "prints usage information" do
      output =
        capture_io(fn ->
          BeamDcd.CLI.main(["--help"])
        end)

      assert output =~ "beam_dcd - BEAM Dead Code Detector"
      assert output =~ "Usage:"
      assert output =~ "--format"
    end

    test "prints usage when no arguments given" do
      output =
        capture_io(fn ->
          BeamDcd.CLI.main([])
        end)

      assert output =~ "beam_dcd - BEAM Dead Code Detector"
    end
  end

  describe "main/1 with beam paths" do
    test "analyzes specified beam directories" do
      output =
        capture_io(fn ->
          BeamDcd.CLI.main(["_build/test/lib/beam_dcd/ebin"])
        end)

      assert output =~ "Unused Public Functions" or output =~ "No unused public functions"
    end

    test "supports --format json" do
      output =
        capture_io(fn ->
          BeamDcd.CLI.main(["_build/test/lib/beam_dcd/ebin", "--format", "json"])
        end)

      assert {:ok, _} = JSON.decode(output)
    end
  end
end
