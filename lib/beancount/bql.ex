defmodule Beancount.BQL do
  @moduledoc """
  Native Beancount Query Language (BQL) parser and evaluator.

  Parses arbitrary BQL strings into an AST and evaluates them against a
  compiled fact base produced by `Beancount.Engine.Elixir.CompiledLedger`.

  ## Examples

      iex> {:ok, query} = Beancount.BQL.parse("SELECT account, sum(position) AS balance GROUP BY account")
      iex> query.select |> length()
      2

  See `guides/query_engine.md` for supported grammar and performance notes.
  """

  alias Beancount.BQL.Parser
  alias Beancount.Engine.Elixir.{CompiledLedger, QueryEngine}
  alias Beancount.Query.Result

  @type query :: map()

  @doc """
  Parse a BQL string into a query struct.

  ## Examples

      iex> bql = "SELECT account, sum(position) AS balance WHERE account ~ " <> ~s(") <> "^Assets" <> ~s(") <> " GROUP BY account ORDER BY account"
      iex> {:ok, query} = Beancount.BQL.parse(bql)
      iex> query.where != nil
      true

  """
  @spec parse(binary()) :: {:ok, query()} | {:error, term()}
  def parse(bql) when is_binary(bql), do: Parser.parse(bql)

  @doc """
  Evaluate a parsed BQL query against a compiled ledger.

  ## Examples

      iex> ledger = [
      ...>   Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      ...>   Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      ...>   Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      ...>   Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      ...>     Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      ...>     Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ...>   ])
      ...> ]
      iex> compiled = Beancount.Engine.Elixir.CompiledLedger.compile(ledger)
      iex> {:ok, query} = Beancount.BQL.parse("SELECT account, sum(position) AS balance GROUP BY account ORDER BY account")
      iex> {:ok, %Beancount.Query.Result{columns: ["account", "balance"]}} = Beancount.BQL.evaluate(query, compiled)

  """
  @spec evaluate(query(), CompiledLedger.t()) :: {:ok, Result.t()} | {:error, term()}
  def evaluate(query, %CompiledLedger{} = compiled) do
    QueryEngine.run(query, compiled)
  end
end
