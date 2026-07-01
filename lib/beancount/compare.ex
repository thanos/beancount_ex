defmodule Beancount.Compare do
  @moduledoc """
  Compare two engines on identical input within the v0.4 parity contract.

  Equivalence is asserted for structural `check/1` results (by error category)
  and the canned report query set (`balances`, `balance_sheet`, `income_statement`,
  `holdings`).
  """

  alias Beancount.Engine.Elixir.ErrorCategory
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

  Returns `{:ok, :equivalent}` when normalized results match, or
  `{:error, %Diff{}}` describing the first mismatch.

  ## Examples

      iex> ledger = [
      ...>   Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      ...>   Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      ...>   Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      ...>   Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
      ...>     Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      ...>     Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ...>   ])
      ...> ]
      iex> Beancount.Compare.compare(Beancount.Engine.Elixir, Beancount.Engine.Elixir, ledger)
      {:ok, :equivalent}

  """
  @spec compare(module(), module(), Beancount.directive() | binary()) ::
          {:ok, :equivalent} | {:error, Diff.t()}
  def compare(oracle, native, input) when is_atom(oracle) and is_atom(native) do
    text = ledger_text(input)
    oracle_result = run_check(oracle, text)
    native_result = run_check(native, text)

    cond do
      check_ok?(oracle_result) and check_ok?(native_result) ->
        with :ok <- compare_check_results(oracle_result, native_result),
             :ok <- compare_canned_queries(oracle, native, text) do
          {:ok, :equivalent}
        end

      equivalent_check?(oracle_result, native_result) ->
        {:ok, :equivalent}

      true ->
        {:error,
         %Diff{
           callback: :check,
           oracle: normalize_check(oracle_result),
           native: normalize_check(native_result),
           message: "check/1 results differ"
         }}
    end
  end

  defp check_ok?(%Result{normalized: %{status: :ok}}), do: true
  defp check_ok?(_), do: false

  defp compare_check_results(oracle_result, native_result) do
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

  defp ledger_text(input) when is_binary(input), do: input
  defp ledger_text(input) when is_list(input), do: Beancount.render(input)

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
    left_norm = normalize_check(left)
    right_norm = normalize_check(right)

    left_norm.status == right_norm.status and
      left_norm.error_categories == right_norm.error_categories and
      other_errors_equivalent?(left_norm.other_errors, right_norm.other_errors)
  end

  # bean-check echoes directive and posting lines under errors; the native engine
  # does not. When only one side has uncategorized messages, treat them as
  # equivalent if categories already match.
  defp other_errors_equivalent?([], []), do: true
  defp other_errors_equivalent?([], _oracle), do: true
  defp other_errors_equivalent?(_native, []), do: true
  defp other_errors_equivalent?(left, right), do: left == right

  defp equivalent_query?(%QueryResult{} = left, %QueryResult{} = right) do
    normalize_query(left) == normalize_query(right)
  end

  defp normalize_check(%Result{normalized: %{status: status, errors: errors}}) do
    {categories, other_messages} =
      Enum.map_reduce(errors, [], fn error, others ->
        categorize_error(error, others)
      end)

    %{
      status: status,
      error_categories: categories |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort(),
      other_errors: other_messages |> Enum.sort()
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
        cell -> cell |> String.trim() |> normalize_position_cell()
      end)
    end)
  end

  defp normalize_position_cell(cell) do
    cell
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&normalize_decimal_string/1)
    |> Enum.sort()
    |> Enum.join(", ")
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

  # Lines bean-check prints as context below a real error (not standalone messages).
  defp cli_context_line?(message) when is_binary(message) do
    String.match?(message, ~r/^\d{4}-\d{2}-\d{2}\s/) or
      String.match?(message, ~r/^[A-Z][A-Za-z0-9:]*:[A-Za-z0-9:]+\s/) or
      String.match?(message, ~r/^[A-Z][A-Za-z0-9:]*:[A-Za-z0-9:]+\s*$/)
  end

  defp categorize_error(%{message: message} = error, others) do
    case ErrorCategory.categorize(error) do
      :other ->
        if cli_context_line?(message), do: {nil, others}, else: {nil, [message | others]}

      category ->
        {category, others}
    end
  end
end
