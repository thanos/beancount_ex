defmodule Beancount.StorageTest do
  use ExUnit.Case, async: false

  alias Beancount.{Repo, Storage}

  setup do
    Storage.clear()
    on_exit(fn -> Storage.clear() end)
    :ok
  end

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
    ])
  ]

  test "store/1 and load/0 round-trip directives" do
    assert {:ok, 4} = Storage.store(@ledger)

    loaded = Storage.load()
    assert length(loaded) == 4

    opens = Enum.filter(loaded, &match?(%Beancount.Directives.Open{}, &1))
    assert length(opens) == 3

    txns = Enum.filter(loaded, &match?(%Beancount.Directives.Transaction{}, &1))
    assert length(txns) == 1
    txn = hd(txns)
    assert txn.narration == "Salary"
    assert length(txn.postings) == 2
  end

  test "store/1 with transaction preserves postings and cost specs" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
        Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
          cost: %Beancount.CostSpec{per_amount: Decimal.new("150"), per_currency: "USD"}
        ),
        Beancount.posting("Assets:Cash", Decimal.new("-1500"), "USD")
      ])
    ]

    assert {:ok, 3} = Storage.store(ledger)

    loaded = Storage.load()
    txn = Enum.find(loaded, &match?(%Beancount.Directives.Transaction{}, &1))
    [stock_posting, cash_posting] = txn.postings

    assert stock_posting.account == "Assets:Stocks"
    assert Decimal.equal?(stock_posting.amount, Decimal.new("10"))
    assert stock_posting.cost.per_currency == "USD"
    assert Decimal.equal?(stock_posting.cost.per_amount, Decimal.new("150"))

    assert cash_posting.account == "Assets:Cash"
    assert Decimal.equal?(cash_posting.amount, Decimal.new("-1500"))
  end

  test "clear/0 removes all directives" do
    Storage.store(@ledger)
    assert length(Storage.load()) == 4

    Storage.clear()
    assert Storage.load() == []
  end

  test "import_file/1 and export_file/1 round-trip" do
    path = Path.join(System.tmp_dir!(), "storage_test_#{System.unique_integer([:positive])}.bean")
    File.write!(path, Beancount.render(@ledger))
    on_exit(fn -> File.rm(path) end)

    assert {:ok, 4} = Storage.import_file(path)

    export_path =
      Path.join(System.tmp_dir!(), "storage_export_#{System.unique_integer([:positive])}.bean")

    on_exit(fn -> File.rm(export_path) end)

    assert :ok = Storage.export_file(export_path)

    original = File.read!(path)
    exported = File.read!(export_path)
    assert original == exported
  end

  test "load/0 returns directives in date order" do
    ledger = [
      Beancount.open(~D[2026-01-02], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"])
    ]

    Storage.store(ledger)

    loaded = Storage.load()
    [first, second] = Enum.filter(loaded, &match?(%Beancount.Directives.Open{}, &1))
    assert first.date == ~D[2026-01-01]
    assert second.date == ~D[2026-01-02]
  end
end
