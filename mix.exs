defmodule Brama.MixProject do
  use Mix.Project

  @version "1.0.1"
  @source_url "https://github.com/ihorkatkov/brama"
  @description "An Elixir-native circuit breaker library for reliable connection management with external dependencies"

  def project do
    [
      app: :brama,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix],
        plt_core_path: "priv/plts/",
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      # Test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex.pm package information
      description: @description,
      package: package(),
      docs: docs(),
      name: "Brama",
      source_url: @source_url
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Brama.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.30", only: [:dev, :test, :docs], runtime: false},
      {:telemetry, "~> 1.2"},
      {:decorator, "~> 1.4"}
    ]
  end

  defp package do
    [
      name: "brama",
      maintainers: ["Ihor Katkov"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/brama"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE SPECS.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "SPECS.md",
        "specs/architecture.md",
        "specs/circuit_breaking.md",
        "specs/status_notifications.md",
        "specs/connection_monitoring.md",
        "specs/self_healing.md",
        "specs/failure_isolation.md",
        "specs/configuration.md",
        "specs/testing_strategy.md",
        "specs/api.md"
      ],
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
