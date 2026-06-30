defmodule Beancount.MixProject do
  use Mix.Project

  @version "0.1.0-pre"
  @source_url "https://github.com/beancount-ex/beancount_ex"

  def project do
    [
      app: :beancount_ex,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_ignore_filters: [&String.contains?(&1, "/fixtures/")],
      test_coverage: [summary: [threshold: 80]],
      dialyzer: dialyzer(),
      name: "beancount_ex",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Beancount.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:decimal, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:stream_data, "~> 1.0", only: [:test, :dev]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    An idiomatic Elixir interface to Beancount that serves as the long-term \
    behavioral oracle for a future native Elixir General Ledger.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib guides .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "guides/getting_started.md",
        "guides/rendering.md",
        "guides/engines.md",
        "guides/golden_files.md",
        "guides/property_testing.md",
        "guides/oracle_strategy.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.?/
      ],
      groups_for_modules: [
        "Public API": [Beancount],
        Directives: ~r/Beancount\.Directives\..*/,
        Engine: [Beancount.Engine, Beancount.Engine.CLI, Beancount.Checker],
        Rendering: [Beancount.Directive, Beancount.Renderer],
        Results: [Beancount.Result, Beancount.Normalizer],
        Testing: [Beancount.Golden, Beancount.Property]
      ],
      source_ref: "v#{@version}"
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts",
      plt_local_path: "priv/plts"
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "test"
      ]
    ]
  end
end
