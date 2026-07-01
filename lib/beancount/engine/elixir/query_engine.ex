defmodule Beancount.Engine.Elixir.QueryEngine do
  @moduledoc false

  alias Beancount.BQL.AST.{Column, Order, Query}
  alias Beancount.Engine.Elixir.{CompiledLedger, FactBase, Inventory, Lot, PostingAmount}
  alias Beancount.Query.Result

  @spec run(Query.t(), CompiledLedger.t()) :: {:ok, Result.t()} | {:error, term()}
  def run(%Query{} = query, %CompiledLedger{fact_base: fact_base, index: index}) do
    cond do
      journal_query?(query) ->
        account = journal_account(query)
        {:ok, journal(fact_base, index, account, query)}

      holdings_query?(query) ->
        {:ok, holdings(fact_base, query)}

      balance_query?(query) ->
        {:ok, balance_report(fact_base, query)}

      true ->
        {:error, {:unsupported_bql, query}}
    end
  end

  defp journal_query?(query) do
    columns = Enum.map(query.select, &column_name/1)
    columns == ["date", "flag", "payee", "narration", "position", "balance"]
  end

  defp holdings_query?(query) do
    Enum.any?(query.select, fn
      %Column{expr: {:func, :units, _}} -> true
      _ -> false
    end)
  end

  defp balance_query?(query) do
    Enum.any?(query.select, fn
      %Column{expr: {:func, :sum, [{:ident, "position"}]}} -> true
      %Column{expr: {:func, :sum, [{:func, :position, []}]}} -> true
      _ -> false
    end)
  end

  defp journal_account(%Query{where: {:binary, :eq, {:ident, "account"}, {:string, account}}}),
    do: account

  defp journal_account(_), do: ""

  defp journal(%FactBase{directives: directives}, _index, account, query) do
    {rows, _balance, _currency} =
      Enum.reduce(directives, {[], Decimal.new(0), nil}, fn directive, state ->
        journal_rows_for_directive(directive, account, state)
      end)

    rows =
      sort_rows(rows, query.order_by, [
        "date",
        "flag",
        "payee",
        "narration",
        "position",
        "balance"
      ])

    %Result{
      columns: Enum.map(query.select, &column_name/1),
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  defp journal_rows_for_directive(
         %Beancount.Directives.Transaction{
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

  defp holdings(%FactBase{} = fact_base, query) do
    filter = account_filter(query.where)

    inventory_rows =
      fact_base.inventory
      |> Inventory.holdings()
      |> Enum.filter(fn {account, _} -> filter.(account) end)
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
      fact_base.transaction_accounts
      |> MapSet.to_list()
      |> Enum.concat(Map.keys(inventory_rows))
      |> Enum.uniq()
      |> Enum.filter(filter)
      |> Enum.sort()

    rows =
      asset_accounts
      |> Enum.map(&holdings_row(&1, inventory_rows, fact_base))
      |> Enum.reject(&is_nil/1)

    rows = sort_rows(rows, query.order_by, Enum.map(query.select, &column_name/1))

    %Result{
      columns: Enum.map(query.select, &column_name/1),
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  defp holdings_row(account, inventory_rows, fact_base) do
    case Map.get(inventory_rows, account) do
      row when not is_nil(row) -> row
      _ -> empty_holdings_row(account, fact_base)
    end
  end

  defp empty_holdings_row(account, %FactBase{opens: opens}) do
    if Map.has_key?(opens, account), do: [account, "", ""], else: nil
  end

  defp balance_report(%FactBase{} = fact_base, query) do
    filter = account_filter(query.where)

    accounts =
      fact_base.opens
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.union(fact_base.transaction_accounts)
      |> MapSet.to_list()
      |> Enum.filter(filter)
      |> Enum.sort()

    rows =
      accounts
      |> Enum.map(fn account ->
        position = account_position(fact_base.inventory, account)
        [account, position]
      end)
      |> Enum.filter(&include_balance_row?(&1, fact_base))

    column_names = Enum.map(query.select, &column_name/1)
    rows = sort_rows(rows, query.order_by, column_names)

    %Result{
      columns: column_names,
      rows: rows,
      raw: "",
      status: :ok
    }
  end

  defp include_balance_row?([account, ""], %FactBase{opens: opens, transaction_accounts: txn}) do
    Map.has_key?(opens, account) and MapSet.member?(txn, account)
  end

  defp include_balance_row?([_account, position], _fact_base), do: position != ""

  defp account_filter({:binary, :regex, {:ident, "account"}, {:string, pattern}}) do
    regex = Regex.compile!(pattern)
    fn account -> Regex.match?(regex, account) end
  end

  defp account_filter({:binary, :eq, {:ident, "account"}, {:string, account}}) do
    fn candidate -> candidate == account end
  end

  defp account_filter(_), do: fn _ -> true end

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

    formatted =
      Enum.map(cost_lots, &format_lot_position(&1, currency)) ++
        format_plain_lots(plain_lots, currency)

    formatted
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

  defp posting_position(_), do: ""

  defp add_amount(balance, %Decimal{} = amount), do: Decimal.add(balance, amount)
  defp add_amount(balance, _), do: balance

  defp format_balance(%Decimal{} = balance, currency) when is_binary(currency) do
    format_decimal(balance) <> " " <> currency
  end

  defp format_balance(%Decimal{} = balance, _), do: format_decimal(balance)

  defp format_decimal(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  defp column_name(%Column{as: alias}) when is_binary(alias), do: alias

  defp column_name(%Column{expr: {:ident, name}}), do: name
  defp column_name(%Column{expr: {:func, name, _}}), do: Atom.to_string(name)

  defp sort_rows(rows, [], _columns), do: rows

  defp sort_rows(rows, orders, columns) do
    Enum.sort_by(rows, fn row ->
      Enum.map(orders, fn %Order{expr: expr, direction: direction} ->
        index = Enum.find_index(columns, &(&1 == expr_name(expr)))
        value = Enum.at(row, index)
        {direction_value(direction), value || ""}
      end)
    end)
  end

  defp direction_value(:asc), do: 0
  defp direction_value(:desc), do: 1

  defp expr_name({:ident, name}), do: name
  defp expr_name({:func, name, _}), do: Atom.to_string(name)
end
