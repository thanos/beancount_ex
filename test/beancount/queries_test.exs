defmodule Beancount.QueriesTest do
  use ExUnit.Case, async: false

  alias Beancount.{Queries, Storage}

  setup do
    Storage.clear()
    on_exit(fn -> Storage.clear() end)

    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.transaction(~D[2026-01-15], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ]),
      Beancount.transaction(~D[2026-02-15], "*", nil, "ATM", [
        Beancount.posting("Assets:Cash", Decimal.new("50"), "USD"),
        Beancount.posting("Assets:Bank", Decimal.new("-50"), "USD")
      ])
    ]

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
end
