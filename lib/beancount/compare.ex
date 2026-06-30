defmodule Beancount.Compare do
  @moduledoc """
  Compare two engines on identical input within the v0.3 parity contract.

  Equivalence is asserted for structural `check/1` results and the canned
  report query set (`balances`, `balance_sheet`, `income_statement`,
  `holdings`). Full booking semantics are excluded until v0.4.
  """

  alias Beancount.Property.Diff
  alias Beancount.Query.Result, as: QueryResult
  alias Beancount.Result

  @canned_queries [
    {"balances", "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"},
    {"balance_sheet",
     "SELECT account, sum(position) AS balance WHERE account ~ \"^(Assets|Liabilities|Equity)\" GROUP BY account ORDER BY account"},
    {"income_statement",
     "SELECT account, sum(position) AS balance WHERE account ~ \"^(Income|Expenses)\" GROUP BY account ORDER BY account"},
    {"holdings",
     "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"}
  ]

  @doc """
  Run `check` and canned reports through both engines on the same input.

  Returns `{:ok, :equivalent}` when normalized results match,
  `{:ok, :deferred}` when the ledger uses constructs outside the v0.3 parity
  contract (`pad`, `include`), or `{:error, %Diff{}}` describing the first
  mismatch.
  """
  @spec compare(module(), module(), Beancount.directive() | binary()) ::
          {:ok, :equivalent | :deferred} | {:error, Diff.t()}
  def compare(oracle, native, input) when is_atom(oracle) and is_atom(native) do
    text = ledger_text(input)

    if deferred_ledger?(text) do
      {:ok, :deferred}
    else
      do_compare(oracle, native, text)
    end
  end

  defp do_compare(oracle, native, text) do
    with :ok <- compare_check(oracle, native, text),
         :ok <- compare_canned_queries(oracle, native, text) do
      {:ok, :equivalent}
    end
  end

  defp deferred_ledger?(text) do
    Regex.match?(~r/^\d{4}-\d{2}-\d{2}\s+pad\s/m, text) or
      Regex.match?(~r/^include\s/m, text)
  end

  defp ledger_text(input) when is_binary(input), do: input
  defp ledger_text(input) when is_list(input), do: Beancount.render(input)

  defp compare_check(oracle, native, text) do
    oracle_result = run_check(oracle, text)
    native_result = run_check(native, text)

    if equivalent_check?(oracle_result, native_result) do
      :ok
    else
      {:error,
       %Diff{
         callback: :check,
         oracle: normalize_check(oracle_result),
         native: normalize_check(native_result),
         message: "check/1 results differ"
       }}
    end
  end

  defp compare_canned_queries(oracle, native, text) do
    Enum.reduce_while(@canned_queries, :ok, fn {name, bql}, :ok ->
      compare_named_query(oracle, native, text, name, bql)
    end)
  end

  defp compare_named_query(oracle, native, text, name, bql) do
    case {run_query(oracle, text, bql), run_query(native, text, bql)} do
      {{:ok, oracle_query}, {:ok, native_query}} ->
        if equivalent_query?(oracle_query, native_query) do
          {:cont, :ok}
        else
          {:halt,
           {:error,
            %Diff{
              callback: :query,
              oracle: normalize_query(oracle_query),
              native: normalize_query(native_query),
              message: "query #{name} results differ"
            }}}
        end

      {{:error, diff}, _} ->
        {:halt, {:error, diff}}

      {_, {:error, diff}} ->
        {:halt, {:error, diff}}
    end
  end

  defp run_check(engine, text) do
    case engine.check(text) do
      {:ok, result} -> result
      {:error, result} -> result
    end
  end

  defp run_query(engine, text, bql) do
    case engine.query(text, bql) do
      {:ok, result} -> {:ok, result}
      {:error, %Result{} = result} -> {:error, query_diff(result)}
    end
  end

  defp query_diff(%Result{normalized: normalized}) do
    %Diff{
      callback: :query,
      oracle: normalized,
      native: nil,
      message: "query failed"
    }
  end

  defp equivalent_check?(%Result{} = left, %Result{} = right) do
    normalize_check(left) == normalize_check(right)
  end

  defp equivalent_query?(%QueryResult{} = left, %QueryResult{} = right) do
    normalize_query(left) == normalize_query(right)
  end

  defp normalize_check(%Result{normalized: normalized}) do
    %{
      normalized
      | errors: Enum.map(normalized.errors, &%{&1 | line: nil})
    }
  end

  defp normalize_query(%QueryResult{columns: columns, rows: rows}) do
    %{
      columns: columns,
      rows: rows |> normalize_rows() |> Enum.sort()
    }
  end

  defp normalize_rows(rows) do
    Enum.map(rows, fn row ->
      Enum.map(row, fn
        <<>> -> ""
        cell -> cell |> String.trim() |> normalize_decimal_string()
      end)
    end)
  end

  defp normalize_decimal_string(cell) do
    case Regex.run(~r/^(-?\d+(?:\.\d+)?)\s+(.+)$/, cell) do
      [_, number, currency] ->
        normalized =
          number |> Decimal.new() |> Decimal.normalize() |> Decimal.to_string(:normal)

        normalized <> " " <> currency

      _ ->
        cell
    end
  end
end
