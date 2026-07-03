defmodule Beancount.Engine.Elixir.PadResolverTest do
  use ExUnit.Case, async: true

  alias Beancount.Directives.{Balance, Pad}
  alias Beancount.Engine.Elixir.{Inventory, PadResolver}

  test "resolve_pad/3 returns no transaction when balance already matches" do
    inventory =
      Inventory.new()
      |> then(fn inv ->
        {:ok, inv} =
          Inventory.apply_posting(
            inv,
            "Assets:Cash",
            Beancount.posting("Assets:Cash", Decimal.new("5"), "USD"),
            nil
          )

        inv
      end)

    pad = %Pad{date: ~D[2026-01-02], account: "Assets:Cash", source_account: "Equity:Opening"}

    balance = %Balance{
      account: "Assets:Cash",
      amount: Decimal.new("5"),
      currency: "USD",
      date: ~D[2026-01-03]
    }

    assert {:ok, ^inventory, nil} = PadResolver.resolve_pad(pad, balance, inventory)
  end

  test "resolve_pad/3 builds a pad transaction when balance differs" do
    pad = %Pad{date: ~D[2026-01-02], account: "Assets:Cash", source_account: "Equity:Opening"}

    balance = %Balance{
      account: "Assets:Cash",
      amount: Decimal.new("5"),
      currency: "USD",
      date: ~D[2026-01-03]
    }

    assert {:ok, _inventory, %Beancount.Directives.Transaction{narration: "Pad"} = txn} =
             PadResolver.resolve_pad(pad, balance, Inventory.new())

    [cash, equity] = txn.postings
    assert cash.account == "Assets:Cash"
    assert Decimal.equal?(cash.amount, Decimal.new("5"))
    assert equity.account == "Equity:Opening"
    assert Decimal.equal?(equity.amount, Decimal.new("-5"))
  end
end
