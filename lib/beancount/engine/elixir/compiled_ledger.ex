defmodule Beancount.Engine.Elixir.CompiledLedger do
  @moduledoc """
  Compile-once, query-many ledger for the native BQL engine.

  Processes directives through booking, pad resolution, and balance checks once,
  then materializes a fact base for repeated BQL evaluation.

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
      iex> {:ok, %Beancount.Query.Result{}} = Beancount.Engine.Elixir.CompiledLedger.query(compiled, query)

  """

  alias Beancount.BQL
  alias Beancount.Engine.Elixir.{DirectiveSort, FactBase, Index, Ledger, QueryEngine}
  alias Beancount.Query.Result

  defstruct fact_base: nil, index: nil, owner: nil

  @type t :: %__MODULE__{
          fact_base: map(),
          index: map() | nil,
          owner: pid() | nil
        }

  @doc """
  Process directives once and build the queryable fact base.
  """
  @spec compile([Beancount.Directive.t()]) :: t()
  def compile(directives) when is_list(directives) do
    ordered = DirectiveSort.order(directives)
    ledger = ordered |> Ledger.new() |> Ledger.process(ordered)
    fact_base = FactBase.from_ledger(ledger, ordered)

    index =
      if length(directives) > Index.threshold() do
        Index.create(fact_base)
      end

    %__MODULE__{fact_base: fact_base, index: index, owner: self()}
  end

  @doc """
  Evaluate a parsed BQL query against this compiled ledger.
  """
  @spec query(t(), BQL.query()) :: {:ok, Result.t()} | {:error, term()}
  def query(%__MODULE__{} = compiled, query) do
    QueryEngine.run(query, compiled)
  end

  @doc """
  Release ETS index tables owned by this compiled ledger.
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{index: index}) do
    Index.destroy(index)
  end
end
