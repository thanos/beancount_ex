defmodule Beancount.Engine.Elixir.Reports do
  @moduledoc false

  alias Beancount.Directives.{Open, Transaction}
  alias Beancount.Engine.Elixir.{Inventory, Ledger, Lot, PostingAmount}
  alias Beancount.Query.Result
  alias Beancount.Result, as: CheckResult

  @canned_balance "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
  @canned_balance_sheet "SELECT account, sum(position) AS balance WHERE account ~ \"^(Assets|Liabilities|Equity)\" GROUP BY account ORDER BY account"
  @canned_income "SELECT account, sum(position) AS balance WHERE account ~ \"^(Income|Expenses)\" GROUP BY account ORDER BY account"
  @canned_holdings "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"

  @spec run([Beancount.Directive.t()], binary()) ::
          {:ok, Result.t()} | {:error, CheckResult.t()}
  def run(directives, bql) do
    normalized = normalize_bql(bql)

    cond do
      normalized == normalize_bql(@canned_balance) ->
        balances(directives)

      normalized == normalize_bql(@canned_balance_sheet) ->
        balance_sheet(directives)

      normalized == normalize_bql(@canned_income) ->
        income_statement(directives)

      normalized == normalize_bql(@canned_holdings) ->
        holdings(directives)

      journal_query?(normalized) ->
        account = journal_account(normalized)
        journal(directives, account)

      true ->
        unsupported_bql(bql)
    end
  end

  def balances(directives, filter \\ fn _ -> true end) do
    ledger = build_ledger(directives)

    rows =
      all_accounts(directives)
      |> Enum.filter(filter)
      |> Enum.sort()
      |> Enum.map(fn account -> [account, account_position(ledger.inventory, account)] end)
      |> Enum.filter(&include_balance_row?(&1, ledger, directives))

    {:ok, %Result{columns: ["account", "balance"], rows: rows, raw: "", status: :ok}}
  end

  def balance_sheet(directives) do
    balances(directives, &account_type?(&1, ~w(Assets Liabilities Equity)))
  end

  def income_statement(directives) do
    balances(directives, &account_type?(&1, ~w(Income Expenses)))
  end

  def holdings(directives, filter \\ &account_type?(&1, ~w(Assets))) do
    ledger = build_ledger(directives)
    txn_accounts = transaction_accounts(directives)

    inventory_rows =
      ledger.inventory
      |> Inventory.holdings()
      |> Enum.filter(fn {account, _} -> filter.(account) end)
      |> Enum.map(fn {account, {units, unit_currency, cost, cost_currency}} ->
        {account,
         [
           account,
           format_decimal(units) <> " " <> unit_currency,
           format_holding_cost(cost, unit_currency, cost_currency) <> " " <> cost_currency
         ]}
      end)
      |> Map.new()

    asset_accounts =
      txn_accounts
      |> MapSet.union(MapSet.new(Map.keys(inventory_rows)))
      |> MapSet.to_list()
      |> Enum.filter(filter)
      |> Enum.sort()

    rows =
      asset_accounts
      |> Enum.map(&holdings_row_for_account(&1, inventory_rows, ledger))
      |> Enum.reject(&is_nil/1)

    {:ok, %Result{columns: ["account", "units", "cost"], rows: rows, raw: "", status: :ok}}
  end

  def journal(directives, account) do
    {rows, _balance, _currency} =
      Enum.reduce(directives, {[], Decimal.new(0), nil}, fn directive, state ->
        journal_rows_for_directive(directive, account, state)
      end)

    {:ok,
     %Result{
       columns: ["date", "flag", "payee", "narration", "position", "balance"],
       rows: rows,
       raw: "",
       status: :ok
     }}
  end

  defp journal_query?(bql) do
    String.starts_with?(
      bql,
      "SELECT date, flag, payee, narration, position, balance WHERE account ="
    )
  end

  defp journal_account(bql) do
    case Regex.run(~r/WHERE account = "((?:\\.|[^"\\])*)"/, bql) do
      [_, account] -> String.replace(account, "\\", "")
      _ -> ""
    end
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
        running = add_amount(running, posting.amount)

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

  defp holdings_row_for_account(account, inventory_rows, ledger) do
    case Map.get(inventory_rows, account) do
      row when not is_nil(row) -> row
      _ -> empty_holdings_row(account, ledger)
    end
  end

  defp empty_holdings_row(account, %Ledger{opens: opens}) do
    if Map.has_key?(opens, account), do: [account, "", ""], else: nil
  end

  defp include_balance_row?([account, ""], %Ledger{opens: opens}, directives) do
    Map.has_key?(opens, account) and MapSet.member?(transaction_accounts(directives), account)
  end

  defp include_balance_row?([_account, position], _ledger, _directives), do: position != ""

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
    {cost_lots, plain_lots} = Enum.split_with(lots, &lot_has_cost?/1)

    Enum.map(cost_lots, &format_lot_position(&1, currency)) ++
      format_plain_lots(plain_lots, currency)
  end

  defp lot_has_cost?(%Lot{cost: %Beancount.CostSpec{}}), do: true
  defp lot_has_cost?(_), do: false

  defp format_plain_lots([], _currency), do: []

  defp format_plain_lots(lots, currency) do
    units =
      Enum.reduce(lots, Decimal.new(0), fn %Lot{units: units}, acc -> Decimal.add(acc, units) end)

    [format_lot_position(%Lot{units: units, currency: currency, cost: nil}, currency)]
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

  defp posting_position(%{amount: %Decimal{} = amount, currency: currency})
       when is_binary(currency) do
    format_decimal(amount) <> " " <> currency
  end

  defp posting_position(_posting), do: ""

  defp add_amount(balance, %Decimal{} = amount), do: Decimal.add(balance, amount)
  defp add_amount(balance, _), do: balance

  defp format_balance(%Decimal{} = balance, currency) when is_binary(currency) do
    format_decimal(balance) <> " " <> currency
  end

  defp format_balance(%Decimal{} = balance, _), do: format_decimal(balance)

  defp format_holding_cost(%Decimal{} = cost, unit_currency, cost_currency)
       when unit_currency == cost_currency,
       do: format_decimal(cost)

  defp format_holding_cost(%Decimal{} = cost, _unit_currency, _cost_currency),
    do: format_cost_decimal(cost)

  defp format_cost_decimal(%Decimal{} = decimal) do
    decimal |> Decimal.round(2) |> Decimal.normalize() |> Decimal.to_string(:normal)
  end

  defp all_accounts(directives) do
    directives
    |> Enum.reduce(MapSet.new(), fn
      %Open{account: account}, set -> MapSet.put(set, account)
      %Transaction{postings: postings}, set -> add_posting_accounts(set, postings)
      _, set -> set
    end)
    |> MapSet.to_list()
  end

  defp transaction_accounts(directives) do
    Enum.reduce(directives, MapSet.new(), fn
      %Transaction{postings: postings}, set -> add_posting_accounts(set, postings)
      _, set -> set
    end)
  end

  defp add_posting_accounts(set, postings) do
    Enum.reduce(postings, set, fn posting, acc ->
      if posting_material?(posting), do: MapSet.put(acc, posting.account), else: acc
    end)
  end

  defp posting_material?(%{amount: %Decimal{}, currency: currency}) when is_binary(currency),
    do: true

  defp posting_material?(_), do: false

  defp account_type?(account, roots) do
    Enum.any?(roots, &String.starts_with?(account, &1 <> ":"))
  end

  defp build_ledger(directives) do
    directives
    |> Ledger.new()
    |> Ledger.process(directives)
  end

  defp format_decimal(%Decimal{} = decimal), do: Beancount.Renderer.format_decimal(decimal)

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
