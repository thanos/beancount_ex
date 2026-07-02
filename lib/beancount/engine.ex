defmodule Beancount.Engine do
  @moduledoc """
  Behaviour that every Beancount execution backend must implement.

  The behaviour is the seam that lets `beancount_ex` swap its backend without
  changing the public `Beancount.*` API:

      Beancount  ->  Engine.CLI    (default, wraps real Beancount)
      Beancount  ->  external engine (implements the behaviour)

  The engine is selected via configuration:

      config :beancount_ex, engine: Beancount.Engine.CLI

  A native Elixir General Ledger (`beancount_gl`) is available as a separate
  package that implements this behaviour.

  """

  @doc """
  Render a directive stream into `.bean` text.

  ## Examples

      iex> Beancount.Engine.CLI.render([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
      "2026-01-01 open Assets:Bank USD\\n"

  """
  @callback render(term()) :: binary()

  @doc """
  Check a `.bean` document, returning a normalized `Beancount.Result`.

  ## Examples

  Requires `bean-check` on `PATH`:

      text = "2026-01-01 open Assets:Bank USD\\n"

      if Beancount.Checker.available?() do
        {:ok, %Beancount.Result{}} = Beancount.Engine.CLI.check(text)
      end

  """
  @callback check(binary()) ::
              {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Check a `.bean` file on disk, returning a normalized `Beancount.Result`.

  Engines that shell out to CLI tools should preserve the file path so
  `include` directives resolve relative to the ledger file.

  ## Examples

      path = Path.join(System.tmp_dir!(), "engine_check.bean")
      File.write!(path, "2026-01-01 open Assets:Bank USD\\n")

      if Beancount.Checker.available?() do
        {:ok, _} = Beancount.Engine.CLI.check_file(path)
      end

  """
  @callback check_file(Path.t()) ::
              {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Run a BQL query against a `.bean` document.

  The first argument is the ledger text, the second is a Beancount Query
  Language (BQL) string. Returns a neutral, engine-independent
  `Beancount.Query.Result` on success, or a `Beancount.Result` describing the
  failure otherwise.

  ## Examples

      text = \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD
      2026-01-01 open Equity:Opening USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\"

      if Beancount.Query.available?() do
        {:ok, %Beancount.Query.Result{columns: cols}} =
          Beancount.Engine.CLI.query(text, "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account")

        cols
        # => ["account", "balance"]
      end

  """
  @callback query(binary(), binary()) ::
              {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Return the currently configured engine module.

  ## Examples

      iex> Beancount.Engine.configured()
      Beancount.Engine.CLI

  """
  @spec configured() :: module()
  def configured do
    Application.get_env(:beancount_ex, :engine, Beancount.Engine.CLI)
  end
end
