defmodule Beancount.Engine.Elixir.BookingTest do
  use ExUnit.Case, async: true

  alias Beancount.CostSpec
  alias Beancount.Engine.Elixir.{Booking, Inventory, Lot}

  test "reduce/4 consumes FIFO lots without cost spec" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Cash", "USD", [
        %Lot{units: Decimal.new("10"), currency: "USD", cost: nil},
        %Lot{units: Decimal.new("5"), currency: "USD", cost: nil}
      ])

    posting = Beancount.posting("Assets:Cash", Decimal.new("-12"), "USD")

    assert {:ok, updated} = Booking.reduce(inventory, "Assets:Cash", posting, "FIFO")
    assert Inventory.balance(updated, "Assets:Cash", "USD") |> Decimal.equal?(Decimal.new("3"))
  end

  test "reduce/4 uses LIFO ordering" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Cash", "USD", [
        %Lot{units: Decimal.new("10"), currency: "USD", cost: nil},
        %Lot{units: Decimal.new("5"), currency: "USD", cost: nil}
      ])

    posting = Beancount.posting("Assets:Cash", Decimal.new("-6"), "USD")

    assert {:ok, updated} = Booking.reduce(inventory, "Assets:Cash", posting, "LIFO")
    lots = updated |> Map.fetch!("Assets:Cash") |> Map.fetch!("USD")
    assert [%Lot{units: units}] = lots
    assert Decimal.equal?(units, Decimal.new("9"))
  end

  test "reduce/4 merges lots for AVERAGE booking before reduction" do
    cost_a = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
    cost_b = %CostSpec{per_amount: Decimal.new("20"), per_currency: "USD"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("10"), currency: "AAPL", cost: cost_a},
        %Lot{units: Decimal.new("10"), currency: "AAPL", cost: cost_b}
      ])

    posting = Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL")

    assert {:ok, updated} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "AVERAGE")

    lots = updated |> Map.fetch!("Assets:Stocks") |> Map.fetch!("AAPL")
    assert length(lots) == 1
    assert Decimal.equal?(hd(lots).units, Decimal.new("15"))
  end

  test "reduce/4 strict booking requires unambiguous cost match" do
    cost = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("10"), currency: "AAPL", cost: cost},
        %Lot{units: Decimal.new("10"), currency: "AAPL", cost: cost}
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
        cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
      )

    assert {:error, message} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert message =~ "Ambiguous matches"
  end

  test "reduce/4 strict without cost spec creates short position on empty inventory" do
    posting = Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL")

    assert {:ok, updated} =
             Booking.reduce(Inventory.new(), "Assets:Stocks", posting, "STRICT")

    assert Decimal.equal?(Inventory.balance(updated, "Assets:Stocks", "AAPL"), Decimal.new("-1"))
  end

  test "reduce/4 strict without cost spec consumes a single lot" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("10"), currency: "AAPL", cost: nil}
      ])

    posting = Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL")

    assert {:ok, updated} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert Decimal.equal?(Inventory.balance(updated, "Assets:Stocks", "AAPL"), Decimal.new("9"))
  end

  test "reduce/4 strict with cost spec errors when no lot matches" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{
          units: Decimal.new("10"),
          currency: "AAPL",
          cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
        }
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
        cost: %CostSpec{per_amount: Decimal.new("99"), per_currency: "USD"}
      )

    assert {:error, message} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert message =~ "No position matches"
  end

  test "reduce/4 creates short position when consuming more than available" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Cash", "USD", [
        %Lot{units: Decimal.new("5"), currency: "USD", cost: nil}
      ])

    posting = Beancount.posting("Assets:Cash", Decimal.new("-8"), "USD")

    assert {:ok, updated} = Booking.reduce(inventory, "Assets:Cash", posting, "NONE")

    lots = updated |> Map.fetch!("Assets:Cash") |> Map.fetch!("USD")
    assert [%Lot{units: units, cost: nil}] = lots
    assert Decimal.equal?(units, Decimal.new("-3"))
  end

  test "reduce/4 matches lots by label and date-only cost specs" do
    label_cost = %CostSpec{label: "lot-a"}
    date_cost = %CostSpec{date: ~D[2020-01-01], per_amount: nil}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("10"), currency: "AAPL", cost: label_cost}
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-4"), "AAPL",
        cost: %CostSpec{label: "lot-a"}
      )

    assert {:ok, updated} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert Decimal.equal?(Inventory.balance(updated, "Assets:Stocks", "AAPL"), Decimal.new("6"))

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Bonds", "BOND", [
        %Lot{units: Decimal.new("10"), currency: "BOND", cost: date_cost}
      ])

    posting =
      Beancount.posting("Assets:Bonds", Decimal.new("-2"), "BOND",
        cost: %CostSpec{date: ~D[2020-01-01], per_amount: nil}
      )

    assert {:ok, updated} =
             Booking.reduce(inventory, "Assets:Bonds", posting, "STRICT")

    assert Decimal.equal?(Inventory.balance(updated, "Assets:Bonds", "BOND"), Decimal.new("8"))
  end

  test "reduce/4 falls back to FIFO when cost spec matches multiple lots" do
    cost = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("5"), currency: "AAPL", cost: cost},
        %Lot{units: Decimal.new("5"), currency: "AAPL", cost: cost}
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-7"), "AAPL",
        cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
      )

    assert {:ok, updated} = Booking.reduce(inventory, "Assets:Stocks", posting, "FIFO")
    assert Decimal.equal?(Inventory.balance(updated, "Assets:Stocks", "AAPL"), Decimal.new("3"))
  end

  test "reduce/4 returns insufficient units from strict lot consumption" do
    cost = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("3"), currency: "AAPL", cost: cost}
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
        cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
      )

    assert {:error, "Insufficient units for reduction"} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")
  end

  test "reduce/4 creates short position for AVERAGE with no lots" do
    posting = Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL")

    assert {:ok, updated} =
             Booking.reduce(Inventory.new(), "Assets:Stocks", posting, "AVERAGE")

    assert [%Lot{units: units, cost: nil}] =
             get_in(updated, ["Assets:Stocks", "AAPL"])

    assert Decimal.equal?(units, Decimal.new("-1"))
  end

  test "reduce/4 includes labeled lot details in ambiguous match errors" do
    cost =
      %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD", label: "magic"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("3"), currency: "AAPL", cost: cost},
        %Lot{units: Decimal.new("2"), currency: "AAPL", cost: cost}
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL", cost: cost)

    assert {:error, message} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert message =~ "Ambiguous matches"
    assert message =~ "magic"
  end

  test "reduce/4 reports no match for FIFO with cost and no inventory" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL",
        cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
      )

    assert {:error, message} =
             Booking.reduce(Inventory.new(), "Assets:Stocks", posting, "FIFO")

    assert message =~ "No position matches"
  end

  test "reduce/4 merges average lots when the first lot has nil cost" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("4"), currency: "AAPL", cost: nil},
        %Lot{
          units: Decimal.new("6"),
          currency: "AAPL",
          cost: %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
        }
      ])

    posting = Beancount.posting("Assets:Stocks", Decimal.new("-2"), "AAPL")

    assert {:ok, updated} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "AVERAGE")

    assert Decimal.equal?(Inventory.balance(updated, "Assets:Stocks", "AAPL"), Decimal.new("8"))
  end

  test "reduce/4 merges average lots when later lots have nil cost" do
    cost = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("4"), currency: "AAPL", cost: cost},
        %Lot{units: Decimal.new("6"), currency: "AAPL", cost: nil}
      ])

    posting = Beancount.posting("Assets:Stocks", Decimal.new("-2"), "AAPL")

    assert {:ok, updated} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "AVERAGE")

    assert Decimal.equal?(Inventory.balance(updated, "Assets:Stocks", "AAPL"), Decimal.new("8"))
  end

  test "reduce/4 does not match lots when labels differ" do
    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{
          units: Decimal.new("5"),
          currency: "AAPL",
          cost: %CostSpec{label: "a", per_amount: Decimal.new("10"), per_currency: "USD"}
        }
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL",
        cost: %CostSpec{label: "b", per_amount: Decimal.new("10"), per_currency: "USD"}
      )

    assert {:error, message} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert message =~ "No position matches"
  end

  test "reduce/4 lists per-amount costs in ambiguous strict errors" do
    cost = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}

    inventory =
      Inventory.new()
      |> Inventory.update_lots_at("Assets:Stocks", "AAPL", [
        %Lot{units: Decimal.new("3"), currency: "AAPL", cost: cost},
        %Lot{units: Decimal.new("2"), currency: "AAPL", cost: cost}
      ])

    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("-1"), "AAPL", cost: cost)

    assert {:error, message} =
             Booking.reduce(inventory, "Assets:Stocks", posting, "STRICT")

    assert message =~ "Ambiguous matches"
    assert message =~ "10 USD"
  end
end
