defmodule Beancount.Engine.Elixir.QueryEngineTest do
  use ExUnit.Case, async: true

  alias Beancount.CostSpec
  alias Beancount.Engine.Elixir.{CompiledLedger, QueryEngine}

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Assets:Empty", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2026-02-01], "*", nil, "Clear empty account", [
      Beancount.posting("Assets:Empty", Decimal.new("10"), "USD"),
      Beancount.posting("Equity:Opening", Decimal.new("-10"), "USD")
    ]),
    Beancount.transaction(~D[2026-02-02], "*", nil, "Clear empty account", [
      Beancount.posting("Assets:Empty", Decimal.new("-10"), "USD"),
      Beancount.posting("Equity:Opening", Decimal.new("10"), "USD")
    ])
  ]

  setup do
    compiled = CompiledLedger.compile(@ledger)
    on_exit(fn -> CompiledLedger.close(compiled) end)
    %{compiled: compiled}
  end

  defp run!(compiled, bql) do
    {:ok, query} = Beancount.BQL.parse(bql)
    QueryEngine.run(query, compiled)
  end

  test "returns unsupported error for unknown query shapes", %{compiled: compiled} do
    {:ok, query} = Beancount.BQL.parse("SELECT count(*)")
    assert {:error, {:unsupported_bql, _}} = QueryEngine.run(query, compiled)
  end

  test "balance report includes opened asset accounts with zero balance", %{compiled: compiled} do
    {:ok, %Beancount.Query.Result{rows: rows}} =
      run!(
        compiled,
        "SELECT account, sum(position) AS balance WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account DESC"
      )

    assert ["Assets:Empty", ""] in rows
    assert ["Assets:Bank", "100 USD"] in rows
  end

  test "holdings include empty row for opened asset accounts", %{compiled: compiled} do
    {:ok, %Beancount.Query.Result{rows: rows}} =
      run!(
        compiled,
        "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"
      )

    assert ["Assets:Empty", "", ""] in rows
  end

  test "journal query tracks running balance and skips unrelated accounts", %{compiled: compiled} do
    {:ok, %Beancount.Query.Result{rows: rows}} =
      run!(
        compiled,
        ~s(SELECT date, flag, payee, narration, position, balance WHERE account = "Assets:Bank" ORDER BY date)
      )

    assert ["2026-01-31", "*", "Employer", "Salary", "100 USD", "100 USD"] in rows
  end

  test "balance report formats cost and date-only lots" do
    ledger =
      @ledger ++
        [
          Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"]),
          Beancount.transaction(~D[2026-02-01], "*", nil, "Buy", [
            Beancount.posting("Assets:Stocks", Decimal.new("2"), "AAPL",
              cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
            ),
            Beancount.posting("Assets:Bank", Decimal.new("-20"), "USD")
          ]),
          Beancount.transaction(~D[2026-02-02], "*", nil, "Buy dated lot", [
            Beancount.posting("Assets:Stocks", Decimal.new("1"), "AAPL",
              cost: %CostSpec{date: ~D[2020-01-01], per_amount: nil}
            ),
            Beancount.posting("Assets:Bank", Decimal.new("-1"), "USD")
          ])
        ]

    compiled = CompiledLedger.compile(ledger)

    try do
      {:ok, %Beancount.Query.Result{rows: rows}} =
        run!(
          compiled,
          "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
        )

      assert Enum.any?(rows, fn [account, position] ->
               account == "Assets:Stocks" and position =~ "10 USD" and position =~ "2020-01-01"
             end)
    after
      CompiledLedger.close(compiled)
    end
  end

  test "journal with DESC sort and empty position for unexpanded postings" do
    ledger =
      @ledger ++
        [
          Beancount.open(~D[2026-01-01], "Equity:Other", ["USD"]),
          Beancount.transaction(~D[2026-03-01], "*", nil, "Two elided", [
            Beancount.posting("Equity:Opening", nil, nil),
            Beancount.posting("Equity:Other", nil, nil)
          ])
        ]

    compiled = CompiledLedger.compile(ledger)

    try do
      {:ok, query} =
        Beancount.BQL.parse(
          ~s(SELECT date, flag, payee, narration, position, balance WHERE account = "Equity:Opening" ORDER BY date DESC)
        )

      {:ok, %Beancount.Query.Result{rows: rows}} = QueryEngine.run(query, compiled)

      assert Enum.any?(rows, fn row ->
               Enum.at(row, 0) == "2026-03-01" and Enum.at(row, 4) == ""
             end)
    after
      CompiledLedger.close(compiled)
    end
  end

  test "holdings filtered by account equality omit unopened accounts", %{compiled: compiled} do
    bql =
      "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account = \"Assets:Bank\" GROUP BY account ORDER BY account"

    {:ok, %Beancount.Query.Result{rows: rows}} = run!(compiled, bql)

    assert rows == [["Assets:Bank", "100 USD", "100 USD"]]
  end

  test "holdings preserve unit-currency cost precision" do
    ledger = [
      Beancount.open(~D[2025-12-20], "Assets:Cash", ["EUR"]),
      Beancount.open(~D[2025-12-20], "Assets:Stocks", ["AAPL"]),
      Beancount.transaction(~D[2025-12-20], "*", nil, "Buy", [
        Beancount.posting("Assets:Cash", Decimal.new("-12.08"), "EUR"),
        Beancount.posting("Assets:Stocks", Decimal.new("1.156"), "AAPL",
          price: %{amount: Decimal.new("10.45"), currency: "EUR", type: :unit}
        )
      ])
    ]

    compiled = CompiledLedger.compile(ledger)

    try do
      {:ok, %Beancount.Query.Result{rows: rows}} =
        run!(
          compiled,
          "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"
        )

      assert ["Assets:Stocks", "1.156 AAPL", "1.156 AAPL"] in rows
    after
      CompiledLedger.close(compiled)
    end
  end

  test "journal query without account filter returns rows", %{compiled: compiled} do
    {:ok, query} =
      Beancount.BQL.parse("SELECT date, flag, payee, narration, position, balance ORDER BY date")

    assert {:ok, %Beancount.Query.Result{rows: rows}} = QueryEngine.run(query, compiled)
    assert rows == []
  end

  test "balance query orders by function expression name", %{compiled: compiled} do
    {:ok, %Beancount.Query.Result{rows: rows}} =
      run!(
        compiled,
        "SELECT account, sum(position) GROUP BY account ORDER BY sum(position) DESC"
      )

    assert length(rows) >= 2
    assert hd(rows) != List.last(rows)
  end

  test "balance query accepts sum(position) function form", %{compiled: compiled} do
    {:ok, query} =
      Beancount.BQL.parse("SELECT account, sum(position) GROUP BY account ORDER BY account")

    assert {:ok, %Beancount.Query.Result{rows: rows}} = QueryEngine.run(query, compiled)
    assert ["Assets:Bank", "100 USD"] in rows
  end

  test "balance report aggregates plain and cost lots on one account" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Mixed", ["USD", "AAPL"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
        Beancount.posting("Assets:Mixed", Decimal.new("10"), "USD"),
        Beancount.posting("Equity:Opening", Decimal.new("-10"), "USD")
      ]),
      Beancount.transaction(~D[2026-01-03], "*", nil, "Stock", [
        Beancount.posting("Assets:Mixed", Decimal.new("2"), "AAPL",
          cost: %CostSpec{per_amount: Decimal.new("5"), per_currency: "USD"}
        ),
        Beancount.posting("Equity:Opening", Decimal.new("-10"), "USD")
      ])
    ]

    compiled = CompiledLedger.compile(ledger)

    try do
      {:ok, %Beancount.Query.Result{rows: rows}} =
        run!(
          compiled,
          "SELECT account, sum(position) AS balance WHERE account = \"Assets:Mixed\" GROUP BY account ORDER BY account"
        )

      assert [[_account, position]] = rows
      assert position =~ "10 USD"
      assert position =~ "2 AAPL"
      assert position =~ "5 USD"
    after
      CompiledLedger.close(compiled)
    end
  end
end
