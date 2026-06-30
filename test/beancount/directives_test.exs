defmodule Beancount.DirectivesTest do
  use ExUnit.Case, async: true

  alias Beancount.Directive

  defp render(directive), do: directive |> Directive.to_bean() |> IO.iodata_to_binary()

  test "open with booking method and no currencies" do
    open = Beancount.open(~D[2026-01-01], "Assets:Bank", [], booking: "STRICT")
    assert render(open) == ~s(2026-01-01 open Assets:Bank "STRICT")
  end

  test "open with multiple currencies" do
    open = Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD", "EUR"])
    assert render(open) == "2026-01-01 open Assets:Bank USD,EUR"
  end

  test "close" do
    assert render(Beancount.close(~D[2026-12-31], "Assets:Bank")) ==
             "2026-12-31 close Assets:Bank"
  end

  test "commodity" do
    assert render(Beancount.commodity(~D[2026-01-01], "USD")) == "2026-01-01 commodity USD"
  end

  test "balance" do
    directive = Beancount.balance(~D[2026-01-31], "Assets:Bank", Decimal.new("100.00"), "USD")
    assert render(directive) == "2026-01-31 balance Assets:Bank  100.00 USD"
  end

  test "price" do
    directive = Beancount.price(~D[2026-01-01], "USD", Decimal.new("1.20"), "CAD")
    assert render(directive) == "2026-01-01 price USD 1.20 CAD"
  end

  test "note" do
    assert render(Beancount.note(~D[2026-01-01], "Assets:Bank", "hi")) ==
             ~s(2026-01-01 note Assets:Bank "hi")
  end

  test "document" do
    assert render(Beancount.document(~D[2026-01-01], "Assets:Bank", "a.pdf")) ==
             ~s(2026-01-01 document Assets:Bank "a.pdf")
  end

  test "event" do
    assert render(Beancount.event(~D[2026-01-01], "location", "NYC")) ==
             ~s(2026-01-01 event "location" "NYC")
  end

  test "custom with values" do
    directive = Beancount.custom(~D[2026-01-01], "budget", [Decimal.new("400"), "USD"])
    assert render(directive) == ~s(2026-01-01 custom "budget" 400 "USD")
  end

  test "custom with no values" do
    assert render(Beancount.custom(~D[2026-01-01], "ping")) == ~s(2026-01-01 custom "ping")
  end

  test "standalone posting renders an indented line" do
    posting = Beancount.posting("Assets:Bank", Decimal.new("5"), "USD")
    assert render(posting) == "  Assets:Bank  5 USD"
  end

  test "posting flag and total price annotation" do
    txn =
      Beancount.transaction(~D[2026-01-01], "*", nil, "X", [
        Beancount.posting("Assets:Bank", Decimal.new("5"), "USD", flag: "!"),
        Beancount.posting("Assets:Other", Decimal.new("-5"), "USD",
          price: %{amount: Decimal.new("5"), currency: "EUR", type: :total}
        )
      ])

    rendered = Beancount.render([txn])
    assert rendered =~ "  ! Assets:Bank"
    assert rendered =~ "@@ 5 EUR"
  end
end
