defmodule Beancount.QueriesTest do
  use ExUnit.Case, async: false

  alias Beancount.{Queries, Storage}

  setup do
    Storage.clear()
    on_exit(fn -> Storage.clear() end)

    directives = Beancount.TestFixtures.queries_ledger()

    {:ok, _} = Storage.store(directives)
    :ok
  end

  test "list_opens/1 returns all opens sorted by account" do
    opens = Queries.list_opens()
    assert length(opens) == 3
    accounts = Enum.map(opens, & &1.account)
    assert accounts == ["Assets:Bank", "Assets:Cash", "Income:Salary"]
  end

  test "list_opens/1 with prefix filters by account type" do
    opens = Queries.list_opens(prefix: "Assets")
    assert length(opens) == 2
    assert Enum.all?(opens, &String.starts_with?(&1.account, "Assets:"))
  end

  test "count_transactions_by_date/0 groups by date" do
    counts = Queries.count_transactions_by_date()
    assert length(counts) == 2
    assert {~D[2026-01-15], 1} in counts
    assert {~D[2026-02-15], 1} in counts
  end

  test "find_transactions/1 filters by payee" do
    txns = Queries.find_transactions(payee: "Employer")
    assert length(txns) == 1
    assert hd(txns).payee == "Employer"
  end

  test "find_transactions/1 filters by date range" do
    txns = Queries.find_transactions(from_date: ~D[2026-02-01])
    assert length(txns) == 1
    assert hd(txns).narration == "ATM"
  end

  test "count_by_type/0 counts directives per type" do
    counts = Queries.count_by_type()
    counts_map = Map.new(counts)
    assert counts_map[:opens] == 3
    assert counts_map[:transactions] == 2
    assert counts_map[:closes] == 0
  end

  test "find_transactions/1 filters by narration substring" do
    txns = Queries.find_transactions(narration: "ATM")
    assert length(txns) == 1
    assert hd(txns).narration == "ATM"
  end

  test "find_transactions/1 filters by to_date" do
    txns = Queries.find_transactions(to_date: ~D[2026-01-31])
    assert length(txns) == 1
    assert hd(txns).narration == "Salary"
  end

  test "list_closes/0 returns closes sorted by account" do
    Storage.store([
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.close(~D[2026-12-31], "Assets:Bank")
    ])

    assert [close] = Queries.list_closes()
    assert close.account == "Assets:Bank"
  end

  test "list_prices/1 returns prices for a commodity ordered by date" do
    Storage.store([
      Beancount.price(~D[2026-01-02], "AAPL", Decimal.new("150"), "USD"),
      Beancount.price(~D[2026-01-01], "AAPL", Decimal.new("140"), "USD"),
      Beancount.price(~D[2026-01-01], "GOOG", Decimal.new("200"), "USD")
    ])

    prices = Queries.list_prices("AAPL")
    assert length(prices) == 2
    assert Enum.map(prices, & &1.date) == [~D[2026-01-01], ~D[2026-01-02]]
  end

  test "list_balances/1 returns balance assertions for an account ordered by date" do
    Storage.store([
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.balance(~D[2026-02-01], "Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.balance(~D[2026-03-01], "Assets:Bank", Decimal.new("200"), "USD")
    ])

    balances = Queries.list_balances("Assets:Bank")
    assert length(balances) == 2
    assert Enum.map(balances, & &1.date) == [~D[2026-02-01], ~D[2026-03-01]]
  end

  test "find_transactions/1 combines payee and date-range filters" do
    txns =
      Queries.find_transactions(
        payee: "Employer",
        from_date: ~D[2026-01-01],
        to_date: ~D[2026-01-31]
      )

    assert length(txns) == 1
    assert hd(txns).payee == "Employer"

    # The same payee outside the date range returns nothing.
    assert Queries.find_transactions(payee: "Employer", from_date: ~D[2026-02-01]) == []
  end

  describe "empty database" do
    setup do
      Storage.clear()
      :ok
    end

    test "list/read queries return empty results on a cleared database" do
      assert Queries.list_opens() == []
      assert Queries.list_closes() == []
      assert Queries.list_prices("AAPL") == []
      assert Queries.list_balances("Assets:Bank") == []
      assert Queries.find_transactions(payee: "Employer") == []
      assert Queries.count_transactions_by_date() == []
    end

    test "count_by_type/0 returns zero for every bucket on a cleared database" do
      counts = Queries.count_by_type()
      assert Enum.all?(counts, fn {_type, count} -> count == 0 end)
    end
  end
end
