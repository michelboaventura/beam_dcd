defmodule BeamDcd.MixProject do
  use Mix.Project

  def project do
    [
      app: :beam_dcd,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        flags: [
          :error_handling,
          :underspecs
        ],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp escript do
    [main_module: BeamDcd.CLI]
  end

  defp deps do
    [
      {:credo, "~> 1.2", only: [:test, :dev], runtime: false},
      {:dialyxir, "~> 1.1", only: [:test, :dev], runtime: false},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
