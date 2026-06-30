defmodule Beancount.Engine.Elixir.Reports do
  @moduledoc false

  alias Beancount.Directives.Transaction
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
    balances = compute_balances(directives)

    rows =
      balances
      |> Enum.filter(fn {account, _} -> account_type?(account, ~w(Assets)) end)
      |> Enum.sort_by(fn {account, _} -> account end)
      |> Enum.map(fn {account, {amount, currency}} ->
        position = format_decimal(amount) <> " " <> currency
        [account, position, position]
      end)

    %Result{
      columns: ["account", "units", "cost"],
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  def journal(directives, account) do
    rows =
      directives
      |> Enum.flat_map(&journal_rows_for_directive(&1, account))

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
         account
       ) do
    postings
    |> Enum.filter(&(&1.account == account))
    |> Enum.map(fn posting ->
      [
        Date.to_iso8601(date),
        flag || "",
        payee || "",
        narration || "",
        posting_position(posting),
        ""
      ]
    end)
  end

  defp journal_rows_for_directive(_directive, _account), do: []

  defp posting_position(%{amount: %Decimal{} = amount, currency: currency})
       when is_binary(currency) do
    format_decimal(amount) <> " " <> currency
  end

  defp posting_position(_posting), do: ""

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
        Enum.reduce(postings, balances, &add_posting_balance/2)

      _, balances ->
        balances
    end)
  end

  defp add_posting_balance(posting, balances) do
    case {posting.amount, posting.currency} do
      {%Decimal{} = amount, currency} when is_binary(currency) ->
        Map.update(balances, posting.account, {amount, currency}, fn {existing, _} ->
          {Decimal.add(existing, amount), currency}
        end)

      _ ->
        balances
    end
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
