defmodule Beancount.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Beancount.Property

  property "balanced transactions always render to a binary" do
    check all(txn <- Property.balanced_transaction()) do
      rendered = Beancount.render([txn])
      assert is_binary(rendered)
      assert String.ends_with?(rendered, "\n")
    end
  end

  property "balanced transaction postings sum to zero" do
    check all(txn <- Property.balanced_transaction()) do
      total =
        txn.postings
        |> Enum.map(& &1.amount)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      assert Decimal.equal?(total, Decimal.new(0))
    end
  end

  property "rendering is deterministic" do
    check all(ledger <- Property.ledger()) do
      assert Beancount.render(ledger) == Beancount.render(ledger)
    end
  end

  property "generated ledgers declare an open for every account used" do
    check all(ledger <- Property.ledger()) do
      opened =
        for %Beancount.Directives.Open{account: account} <- ledger,
            into: MapSet.new(),
            do: account

      used =
        for %Beancount.Directives.Transaction{postings: postings} <- ledger,
            %{account: account} <- postings,
            into: MapSet.new(),
            do: account

      assert MapSet.subset?(used, opened)
    end
  end

  property "amount/0 generates positive decimals" do
    check all(amount <- Property.amount()) do
      assert match?(%Decimal{}, amount)
      assert Decimal.positive?(amount)
    end
  end

  property "metadata/0 generates small string-valued maps" do
    check all(metadata <- Property.metadata()) do
      assert is_map(metadata)
      assert map_size(metadata) <= 2
      assert Enum.all?(metadata, fn {_key, value} -> is_binary(value) end)
    end
  end

  property "account/0 and currency/0 produce valid tokens" do
    check all(account <- Property.account(), currency <- Property.currency()) do
      assert account =~ ~r/^[A-Z][A-Za-z]+:[A-Z][A-Za-z]+$/
      assert currency =~ ~r/^[A-Z]+$/
    end
  end

  test "compare/2 is a documented placeholder" do
    assert Property.compare(Beancount.Engine.CLI, Beancount.Engine.CLI) == :not_implemented
  end
end
