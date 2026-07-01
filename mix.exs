defmodule Beancount.MixProject do
  use Mix.Project

  @version "0.5.0"
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
      test_coverage: [tool: ExCoveralls, summary: [threshold: 80]],
      dialyzer: dialyzer(),
      name: "beancount_ex",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
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
      {:decimal, "~> 3.1", override: true},
      {:jason, "~> 1.4"},
      {:nimble_parsec, "~> 1.4"},
      {:explorer, "~> 0.11.1", optional: true},
      {:stream_data, "~> 1.0", only: [:test, :dev]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
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
        "CHANGELOG.md",
        "LICENSE",
        "guides/library.md",
        "guides/accounting/README.md",
        "guides/accounting/getting_started.md",
        "guides/accounting/in_context.md",
        "guides/accounting/cookbook.md",
        "guides/accounting/running_reports.md",
        "guides/getting_started.md",
        "guides/parsing.md",
        "guides/rendering.md",
        "guides/engines.md",
        "guides/querying.md",
        "guides/reporting.md",
        "guides/golden_files.md",
        "guides/booking.md",
        "guides/reconciliation.md",
        "guides/query_engine.md",
        "guides/directive_compiler.md",
        "guides/performance.md",
        "guides/property_testing.md",
        "guides/oracle_strategy.md",
        "guides/livebook/getting_started.livemd",
        "guides/livebook/accounting.livemd",
        "guides/livebook/parsing.livemd",
        "guides/livebook/reporting.livemd"
      ],
      groups_for_extras: [
        Accounting: ~r/guides\/(accounting\/|getting_started\.md)/,
        Library:
          ~r/guides\/(parsing|rendering|engines|querying|reporting|golden_files|booking|reconciliation|performance|property_testing|oracle_strategy|library)\./,
        Livebooks: ~r/guides\/livebook\//
      ],
      groups_for_modules: [
        "Public API": [Beancount, Beancount.Parser, Beancount.Compare],
        Directives: ~r/Beancount\.Directives\..*/,
        Engine: [
          Beancount.Engine,
          Beancount.Engine.CLI,
          Beancount.Engine.Elixir,
          Beancount.Engine.Elixir.CompiledLedger,
          Beancount.BQL,
          Beancount.Checker,
          Beancount.Query
        ],
        Rendering: [Beancount.Directive, Beancount.Renderer],
        Reporting: [Beancount.Report, Beancount.Query.Result, Beancount.Explorer],
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
        "test",
        "dialyzer --format short"
      ],
      verify: &verify/1
    ]
  end

  defp verify(_) do
    steps = [
      {"compile --warnings-as-errors", :dev},
      {"format", :dev},
      {"format --check-formatted", :dev},
      {"credo --strict", :dev},
      # {"sobelow --exit Low", :dev},
      {"dialyzer", :dev},
      {"test --cover", :test},
      {"docs --warnings-as-errors", :dev}
    ]

    Enum.each(steps, fn {task, env} ->
      Mix.shell().info(IO.ANSI.format([:bright, "==> mix #{task}", :reset]))

      mix_executable =
        System.find_executable("mix") ||
          Mix.raise("Could not find `mix` executable on PATH")

      {_, exit_code} =
        System.cmd(mix_executable, String.split(task),
          env: [{"MIX_ENV", to_string(env)}],
          into: IO.stream(:stdio, :line),
          stderr_to_stdout: true
        )

      if exit_code != 0 do
        Mix.raise("mix #{task} failed (exit code #{exit_code})")
      end
    end)

    Mix.shell().info(
      IO.ANSI.format([:green, :bright, "\nAll verification checks passed!", :reset])
    )
  end
end
