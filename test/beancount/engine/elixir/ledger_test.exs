defmodule Beancount.Engine.Elixir.LedgerTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.{Inventory, Ledger}

  test "process/2 applies opens, transactions, balances, and pads" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.pad(~D[2026-01-02], "Assets:Cash", "Equity:Opening"),
      Beancount.balance(~D[2026-01-03], "Assets:Cash", Decimal.new("5"), "USD")
    ]

    ledger = Ledger.process(Ledger.new(), directives)

    assert Map.has_key?(ledger.opens, "Assets:Cash")

    assert Decimal.equal?(
             Inventory.balance(ledger.inventory, "Assets:Cash", "USD"),
             Decimal.new("5")
           )
  end

  test "errors/1 returns validation messages" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Broken", [
        Beancount.posting("Assets:Cash", Decimal.new("10"), "USD"),
        Beancount.posting("Equity:Opening", Decimal.new("-5"), "USD")
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)

    assert Enum.any?(Ledger.errors(ledger), fn %{message: message} ->
             String.contains?(message, "balance")
           end)
  end

  test "inventory/1 returns processed inventory" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Deposit", [
        Beancount.posting("Assets:Cash", Decimal.new("3"), "USD"),
        Beancount.posting("Equity:Opening", Decimal.new("-3"), "USD")
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)

    assert Decimal.equal?(
             Inventory.balance(Ledger.inventory(ledger), "Assets:Cash", "USD"),
             Decimal.new("3")
           )
  end

  test "process/2 records include errors for missing files" do
    ledger =
      Ledger.process(Ledger.new(), [
        %Beancount.Directives.Include{path: "missing.bean"}
      ])

    assert Enum.any?(Ledger.errors(ledger), fn %{message: message} ->
             message =~ "does not match any files"
           end)
  end

  test "process/2 resolves include relative to include_base" do
    dir = Path.join(System.tmp_dir!(), "ledger_include_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    include_path = Path.join(dir, "extra.bean")
    File.write!(include_path, "2026-01-01 open Assets:Cash USD\n")
    on_exit(fn -> File.rm_rf!(dir) end)

    ledger =
      Ledger.new(include_base: include_path)
      |> Ledger.process([
        %Beancount.Directives.Include{path: "extra.bean"}
      ])

    refute Enum.any?(Ledger.errors(ledger), fn %{message: msg} -> msg =~ "does not match" end)
  end

  test "process/2 skips pad transaction when balance already matches" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Seed", [
        Beancount.posting("Assets:Cash", Decimal.new("5"), "USD"),
        Beancount.posting("Equity:Opening", Decimal.new("-5"), "USD")
      ]),
      Beancount.pad(~D[2026-01-03], "Assets:Cash", "Equity:Opening"),
      Beancount.balance(~D[2026-01-04], "Assets:Cash", Decimal.new("5"), "USD")
    ]

    ledger = Ledger.process(Ledger.new(), directives)

    assert Decimal.equal?(
             Inventory.balance(ledger.inventory, "Assets:Cash", "USD"),
             Decimal.new("5")
           )
  end

  test "process/2 applies STRICT booking from open directive" do
    text = """
    2020-01-01 open Assets:Stocks AAPL "STRICT"
    2020-01-01 open Assets:Cash USD
    2020-01-01 open Equity:Opening USD

    2020-01-02 * "Buy"
      Assets:Stocks  10 AAPL {10 USD}
      Assets:Cash  -100 USD

    2020-01-03 * "Sell"
      Assets:Stocks  -5 AAPL {10 USD}
      Assets:Cash   50 USD
    """

    {:ok, directives} = Beancount.parse_text(text)
    ledger = Ledger.process(Ledger.new(), directives)

    assert Decimal.equal?(Inventory.balance(ledger.inventory, "Assets:Stocks", "AAPL"), 5)
  end

  test "process/2 records option validation errors" do
    ledger =
      Ledger.process(Ledger.new(), [
        %Beancount.Directives.Option{name: "inferred_tolerance_default", value: "bad"}
      ])

    assert Enum.any?(Ledger.errors(ledger), fn %{message: message} ->
             message =~ "inferred_tolerance_default"
           end)
  end

  test "process/2 validates parent account balance directives" do
    ledger =
      Ledger.process(Ledger.new(), [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.balance(~D[2026-01-02], "Assets", Decimal.new("1"), "USD")
      ])

    assert Enum.any?(Ledger.errors(ledger), fn %{message: message} ->
             message =~ "Invalid token"
           end)
  end

  test "process/2 infers tolerance from price postings" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD", "EUR"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD", "EUR"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Priced", [
        Beancount.posting("Assets:Bank", Decimal.new("10"), "USD",
          price: %{amount: Decimal.new("1.10"), currency: "EUR", type: :unit}
        ),
        Beancount.posting("Equity:Opening", Decimal.new("-11"), "EUR")
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)
    refute Enum.any?(Ledger.errors(ledger), fn %{message: msg} -> msg =~ "does not balance" end)
  end

  test "process/2 validates non-strict accounts normally when selling at cost" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
        Beancount.posting("Assets:Stocks", Decimal.new("1"), "AAPL",
          cost: %Beancount.CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
        ),
        Beancount.posting("Equity:Opening", Decimal.new("-10"), "USD")
      ]),
      Beancount.transaction(~D[2026-01-03], "*", nil, "Sell", [
        Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL",
          cost: %Beancount.CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
        ),
        Beancount.posting("Equity:Opening", Decimal.new("10"), "USD")
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)
    refute Enum.any?(Ledger.errors(ledger), fn %{message: msg} -> msg =~ "does not balance" end)
  end

  test "process/2 handles pad with cost-basis inventory accounts" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
        Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
          cost: %Beancount.CostSpec{per_amount: Decimal.new("150"), per_currency: "USD"}
        ),
        Beancount.posting("Equity:Opening", Decimal.new("-1500"), "USD")
      ]),
      Beancount.pad(~D[2026-01-03], "Equity:Opening", "Assets:Stocks"),
      Beancount.balance(~D[2026-01-04], "Equity:Opening", Decimal.new("1500"), "USD")
    ]

    ledger = Ledger.process(Ledger.new(), directives)

    assert Decimal.equal?(
             Inventory.balance(ledger.inventory, "Equity:Opening", "USD"),
             Decimal.new("1500")
           )
  end
end
