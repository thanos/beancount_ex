defmodule Beancount.Engine.Elixir.Reports do
  @moduledoc false

  alias Beancount.Directives.{Open, Transaction}
  alias Beancount.Engine.Elixir.{Inventory, Ledger, Lot, PostingAmount}
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
    ledger = build_ledger(directives)
    txn_accounts = transaction_accounts(directives)

    inventory_rows =
      ledger.inventory
      |> Inventory.holdings()
      |> Enum.filter(fn {account, _} -> account_type?(account, ~w(Assets)) end)
      |> Enum.map(fn {account, {units, unit_currency, cost, cost_currency}} ->
        {account,
         [
           account,
           format_decimal(units) <> " " <> unit_currency,
           format_decimal(cost) <> " " <> cost_currency
         ]}
      end)
      |> Map.new()

    asset_accounts =
      txn_accounts
      |> MapSet.union(MapSet.new(Map.keys(inventory_rows)))
      |> MapSet.to_list()
      |> Enum.filter(&account_type?(&1, ~w(Assets)))
      |> Enum.sort()

    rows =
      asset_accounts
      |> Enum.map(&holdings_row_for_account(&1, inventory_rows, ledger))
      |> Enum.reject(&is_nil/1)

    %Result{
      columns: ["account", "units", "cost"],
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  defp holdings_row_for_account(account, inventory_rows, ledger) do
    case Map.get(inventory_rows, account) do
      row when not is_nil(row) -> row
      _ -> empty_holdings_row(account, ledger)
    end
  end

  defp empty_holdings_row(account, ledger) do
    if Map.has_key?(ledger.opens, account), do: [account, "", ""], else: nil
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
      |> PostingAmount.expand_postings()
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
    ledger = build_ledger(directives)
    accounts = known_accounts(directives)
    txn_accounts = transaction_accounts(directives)

    rows =
      accounts
      |> Enum.filter(filter)
      |> Enum.sort()
      |> Enum.map(fn account ->
        [account, account_position(ledger.inventory, account)]
      end)
      |> Enum.filter(&include_balance_row?(&1, ledger, txn_accounts))

    %Result{columns: columns, rows: rows, raw: "", status: :ok}
  end

  defp include_balance_row?([account, ""], ledger, txn_accounts) do
    Map.has_key?(ledger.opens, account) and MapSet.member?(txn_accounts, account)
  end

  defp include_balance_row?([_account, position], _ledger, _txn_accounts), do: position != ""

  defp transaction_accounts(directives) do
    Enum.reduce(directives, MapSet.new(), fn
      %Transaction{postings: postings}, set -> add_posting_accounts(set, postings)
      _, set -> set
    end)
  end

  defp known_accounts(directives) do
    directives
    |> Enum.reduce(MapSet.new(), fn
      %Open{account: account}, set -> MapSet.put(set, account)
      %Transaction{postings: postings}, set -> add_posting_accounts(set, postings)
      _, set -> set
    end)
    |> MapSet.to_list()
  end

  defp add_posting_accounts(set, postings) do
    Enum.reduce(postings, set, fn posting, acc ->
      maybe_add_report_account(acc, posting)
    end)
  end

  defp maybe_add_report_account(acc, posting) do
    if posting_material_for_report?(posting), do: MapSet.put(acc, posting.account), else: acc
  end

  defp posting_material_for_report?(%{amount: %Decimal{}, currency: currency})
       when is_binary(currency),
       do: true

  defp posting_material_for_report?(_), do: false

  defp account_position(inventory, account) do
    case Map.get(inventory, account, %{}) do
      currencies when currencies == %{} -> ""
      currencies -> format_account_currencies(currencies)
    end
  end

  defp format_account_currencies(currencies) do
    currencies
    |> Enum.flat_map(&format_currency_lots/1)
    |> Enum.join(", ")
  end

  defp format_currency_lots({currency, lots}) do
    lots
    |> Enum.group_by(& &1.cost)
    |> Enum.map(&format_grouped_lot(&1, currency))
  end

  defp format_grouped_lot({cost, grouped}, currency) do
    units = sum_lot_units(grouped)
    format_lot_position(%Lot{units: units, currency: currency, cost: cost}, currency)
  end

  defp sum_lot_units(lots) do
    Enum.reduce(lots, Decimal.new(0), fn lot, acc -> Decimal.add(acc, lot.units) end)
  end

  defp format_lot_position(%Lot{units: units, cost: cost}, currency) do
    base = format_decimal(units) <> " " <> currency

    case cost do
      %Beancount.CostSpec{} = spec when not is_nil(spec.per_amount) ->
        base <> " { " <> format_decimal(spec.per_amount) <> " " <> spec.per_currency <> "}"

      %Beancount.CostSpec{date: %Date{} = date} ->
        base <> " {" <> Date.to_iso8601(date) <> "}"

      _ ->
        base
    end
  end

  defp build_ledger(directives) do
    directives
    |> Ledger.new()
    |> Ledger.process(directives)
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
