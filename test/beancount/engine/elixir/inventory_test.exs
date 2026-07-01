defmodule Beancount.Engine.Elixir.InventoryTest do
  use ExUnit.Case, async: true

  alias Beancount.CostSpec
  alias Beancount.Engine.Elixir.{Inventory, Lot}

  test "new/0 and balance/3" do
    inventory = Inventory.new()
    assert Decimal.equal?(Inventory.balance(inventory, "Assets:Cash", "USD"), 0)

    {:ok, inventory} =
      Inventory.apply_posting(
        inventory,
        "Assets:Cash",
        Beancount.posting("Assets:Cash", Decimal.new("10"), "USD"),
        nil
      )

    assert Decimal.equal?(Inventory.balance(inventory, "Assets:Cash", "USD"), 10)
  end

  test "apply_posting/4 ignores postings without decimal amounts" do
    inventory = Inventory.new()

    posting = %Beancount.Directives.Posting{
      account: "Assets:Cash",
      amount: nil,
      currency: nil,
      cost: nil,
      price: nil,
      flag: nil,
      metadata: %{}
    }

    assert {:ok, ^inventory} = Inventory.apply_posting(inventory, "Assets:Cash", posting, nil)
  end

  test "positions/1 and holdings/1 skip zero balances" do
    inventory =
      Inventory.new()
      |> then(fn inv ->
        {:ok, inv} =
          Inventory.apply_posting(
            inv,
            "Assets:Cash",
            Beancount.posting("Assets:Cash", Decimal.new("10"), "USD"),
            nil
          )

        inv
      end)

    assert Inventory.positions(inventory) == %{"Assets:Cash" => [{"USD", Decimal.new("10")}]}

    assert Inventory.holdings(inventory) == %{
             "Assets:Cash" => {Decimal.new("10"), "USD", Decimal.new("10"), "USD"}
           }
  end

  test "lot_cost/1 enriches cost from unit price when per amount is missing" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("5"), "AAPL",
        cost: %CostSpec{per_amount: nil, per_currency: "USD"},
        price: %{amount: Decimal.new("150"), currency: "USD", type: :unit}
      )

    assert %CostSpec{per_amount: per, per_currency: "USD"} = Inventory.lot_cost(posting)
    assert Decimal.equal?(per, Decimal.new("150"))
  end

  test "holdings/1 uses total cost basis when only total_amount is present" do
    lot = %Lot{
      units: Decimal.new("2"),
      currency: "AAPL",
      cost: %CostSpec{total_amount: Decimal.new("300"), total_currency: "USD"}
    }

    inventory = Inventory.update_lots_at(Inventory.new(), "Assets:Stocks", "AAPL", [lot])

    assert %{"Assets:Stocks" => {units, "AAPL", cost, "USD"}} = Inventory.holdings(inventory)
    assert Decimal.equal?(units, Decimal.new("2"))
    assert Decimal.equal?(cost, Decimal.new("300"))
  end

  test "cost_specs_match?/2 compares cost specs and rejects mismatches" do
    left = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
    right = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
    other = %CostSpec{per_amount: Decimal.new("11"), per_currency: "USD"}

    assert Inventory.cost_specs_match?(left, right)
    refute Inventory.cost_specs_match?(left, other)
    refute Inventory.cost_specs_match?(left, nil)
  end

  test "update_lots_at/4 removes empty accounts and currencies" do
    inventory =
      Inventory.update_lots_at(Inventory.new(), "Assets:Cash", "USD", [
        %Lot{units: Decimal.new("1"), currency: "USD", cost: nil}
      ])

    emptied = Inventory.update_lots_at(inventory, "Assets:Cash", "USD", [])
    assert emptied == %{}
  end
end
