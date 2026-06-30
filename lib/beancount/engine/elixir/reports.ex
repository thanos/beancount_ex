defmodule Beancount.Engine.Elixir.Reports do
  @moduledoc false

  alias Beancount.Directives.Transaction
  alias Beancount.Engine.Elixir.PostingAmount
  alias Beancount.Query.Result
  alias Beancount.Result, as: CheckResult

  @raw_canned %{
    "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account" => :balances,
    "SELECT account, sum(position) AS balance WHERE account ~ \"^(Assets|Liabilities|Equity)\" GROUP BY account ORDER BY account" =>
      :balance_sheet,
    "SELECT account, sum(position) AS balance WHERE account ~ \"^(Income|Expenses)\" GROUP BY account ORDER BY account" =>
      :income_statement,
    "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account" =>
      :holdings
  }

  @spec run([Beancount.Directive.t()], binary()) ::
          {:ok, Result.t()} | {:error, CheckResult.t()}
  def run(directives, bql) do
    normalized = normalize_bql(bql)
    canned = Map.new(@raw_canned, fn {key, value} -> {normalize_bql(key), value} end)

    case Map.get(canned, normalized) do
      nil ->
        if journal_query?(normalized) do
          account = journal_account(normalized)
          {:ok, journal(directives, account)}
        else
          unsupported_bql(normalized)
        end

      report ->
        {:ok, apply(__MODULE__, report, [directives])}
    end
  end

  defp journal_query?(bql) do
    String.match?(
      bql,
      ~r/^SELECT date, flag, payee, narration, position, balance WHERE account = "/
    )
  end

  defp journal_account(bql) do
    case Regex.run(~r/WHERE account = "((?:\\.|[^"\\])*)"/, bql) do
      [_, account] -> String.replace(account, "\\", "")
      _ -> ""
    end
  end

  def balances(directives),
    do: balance_report(directives, fn _ -> true end, ["account", "balance"])

  def balance_sheet(directives) do
    balance_report(directives, &account_type?(&1, ~w(Assets Liabilities Equity)), [
      "account",
      "balance"
    ])
  end

  def income_statement(directives) do
    balance_report(directives, &account_type?(&1, ~w(Income Expenses)), ["account", "balance"])
  end

  def holdings(directives) do
    rows =
      directives
      |> compute_holdings()
      |> Enum.filter(fn {account, _} -> account_type?(account, ~w(Assets)) end)
      |> Enum.sort_by(fn {account, _} -> account end)
      |> Enum.map(fn {account, holding} ->
        {units, cost} = format_holding(holding)
        [account, units, cost]
      end)

    %Result{
      columns: ["account", "units", "cost"],
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  def journal(directives, account) do
    {rows, _balance, _currency} =
      Enum.reduce(directives, {[], Decimal.new(0), nil}, fn directive, state ->
        journal_rows_for_directive(directive, account, state)
      end)

    %Result{
      columns: ["date", "flag", "payee", "narration", "position", "balance"],
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  defp journal_rows_for_directive(
         %Transaction{
           date: date,
           flag: flag,
           payee: payee,
           narration: narration,
           postings: postings
         },
         account,
         {rows, balance, currency}
       ) do
    {new_rows, {balance, currency}} =
      postings
      |> Enum.filter(&(&1.account == account))
      |> Enum.map_reduce({balance, currency}, fn posting, {running, currency} ->
        currency = posting.currency || currency
        running = add_posting_amount(running, posting)

        row = [
          Date.to_iso8601(date),
          flag || "",
          payee || "",
          narration || "",
          posting_position(posting),
          format_balance(running, currency)
        ]

        {row, {running, currency}}
      end)

    {rows ++ new_rows, balance, currency}
  end

  defp journal_rows_for_directive(_directive, _account, state), do: state

  defp posting_position(%{amount: %Decimal{} = amount, currency: currency})
       when is_binary(currency) do
    format_decimal(amount) <> " " <> currency
  end

  defp posting_position(_posting), do: ""

  defp add_posting_amount(balance, %{amount: %Decimal{} = amount}),
    do: Decimal.add(balance, amount)

  defp add_posting_amount(balance, _), do: balance

  defp format_balance(%Decimal{} = balance, currency) when is_binary(currency) do
    format_decimal(balance) <> " " <> currency
  end

  defp format_balance(%Decimal{} = balance, _), do: format_decimal(balance)

  defp balance_report(directives, filter, columns) do
    balances = compute_balances(directives)

    rows =
      balances
      |> Enum.filter(fn {account, _balance} -> filter.(account) end)
      |> Enum.sort_by(fn {account, _} -> account end)
      |> Enum.map(fn {account, {amount, currency}} ->
        [account, format_decimal(amount) <> " " <> currency]
      end)

    %Result{columns: columns, rows: rows, raw: "", status: :ok}
  end

  defp compute_balances(directives) do
    Enum.reduce(directives, %{}, fn
      %Transaction{postings: postings}, balances ->
        postings
        |> PostingAmount.expand_postings()
        |> Enum.reduce(balances, &add_posting_balance/2)

      _, balances ->
        balances
    end)
  end

  defp add_posting_balance(posting, balances) do
    case PostingAmount.balance_contribution(posting) do
      {currency, amount} ->
        Map.update(balances, posting.account, {amount, currency}, fn {existing, _} ->
          {Decimal.add(existing, amount), currency}
        end)

      nil ->
        balances
    end
  end

  defp compute_holdings(directives) do
    Enum.reduce(directives, %{}, fn
      %Transaction{postings: postings}, holdings ->
        postings
        |> PostingAmount.expand_postings()
        |> Enum.reduce(holdings, &add_holding/2)

      _, holdings ->
        holdings
    end)
  end

  defp add_holding(posting, holdings) do
    case {posting.amount, posting.currency} do
      {%Decimal{} = amount, currency} when is_binary(currency) ->
        Map.update(
          holdings,
          posting.account,
          holding_state(amount, currency, posting),
          fn state ->
            merge_holding(state, amount, currency, posting)
          end
        )

      _ ->
        holdings
    end
  end

  defp holding_state(amount, currency, posting) do
    %{
      unit_amount: amount,
      unit_currency: currency,
      cost_amount: cost_amount(posting, amount),
      cost_currency: cost_currency(posting, currency)
    }
  end

  defp merge_holding(state, amount, currency, posting) do
    if state.unit_currency == currency do
      %{
        state
        | unit_amount: Decimal.add(state.unit_amount, amount),
          cost_amount: add_optional(state.cost_amount, cost_amount(posting, amount))
      }
    else
      holding_state(amount, currency, posting)
    end
  end

  defp cost_amount(posting, default_amount) do
    case PostingAmount.cost_basis(posting) do
      {_currency, basis} -> basis
      nil -> default_amount
    end
  end

  defp cost_currency(posting, default_currency) do
    case PostingAmount.cost_basis(posting) do
      {currency, _} -> currency
      nil -> default_currency
    end
  end

  defp add_optional(nil, value), do: value
  defp add_optional(existing, value), do: Decimal.add(existing, value)

  defp format_holding(%{
         unit_amount: unit_amount,
         unit_currency: unit_currency,
         cost_amount: cost_amount,
         cost_currency: cost_currency
       }) do
    units = format_decimal(unit_amount) <> " " <> unit_currency
    cost = format_decimal(cost_amount) <> " " <> cost_currency
    {units, cost}
  end

  defp account_type?(account, roots) do
    Enum.any?(roots, &String.starts_with?(account, &1 <> ":"))
  end

  defp format_decimal(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  defp normalize_bql(bql) do
    bql |> String.replace(~r/\s+/, " ") |> String.trim()
  end

  defp unsupported_bql(bql) do
    {:error,
     %CheckResult{
       status: :error,
       exit_status: 1,
       stdout: "unsupported native BQL: #{bql}",
       stderr: "",
       normalized: %{
         status: :error,
         errors: [%{line: nil, message: "unsupported native BQL in Engine.Elixir"}]
       }
     }}
  end
end
