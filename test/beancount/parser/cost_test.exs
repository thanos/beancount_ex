defmodule Beancount.Parser.CostTest do
  use ExUnit.Case, async: true

  alias Beancount.Parser.Cost

  test "parse/1 handles braced, total-only, and label cost specs" do
    assert {:ok, spec} = Cost.parse("{150 USD, 2020-01-01}")
    assert spec.per_amount == Decimal.new("150")
    assert spec.per_currency == "USD"
    assert spec.date == ~D[2020-01-01]

    assert {:ok, spec} = Cost.parse("{{500 USD}}")
    assert spec.total_amount == Decimal.new("500")
    assert spec.total_currency == "USD"
    assert spec.merge == false

    assert {:ok, spec} = Cost.parse(~s({"magic lot"}))
    assert spec.label == "magic lot"

    assert {:ok, spec} = Cost.parse(~s({10 USD, "lot-a"}))
    assert spec.label == "lot-a"
    assert spec.per_amount == Decimal.new("10")
  end

  test "parse/1 handles date-only, per-total, and combined extras" do
    assert {:ok, spec} = Cost.parse("{2020-01-01}")
    assert spec.date == ~D[2020-01-01]

    assert {:ok, spec} = Cost.parse("{10 USD # 500 USD}")
    assert spec.per_amount == Decimal.new("10")
    assert spec.total_amount == Decimal.new("500")
    assert spec.total_currency == "USD"

    assert {:ok, spec} = Cost.parse("{10 USD, 2020-01-01}")
    assert spec.date == ~D[2020-01-01]
    assert spec.per_amount == Decimal.new("10")
  end

  test "parse/1 returns errors for invalid specs" do
    assert {:error, %Beancount.Parser.Error{message: message}} = Cost.parse("not-a-cost")
    assert message =~ "invalid cost spec"

    assert {:error, %Beancount.Parser.Error{message: message}} = Cost.parse("{}")
    assert message =~ "empty cost spec"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Cost.parse("{{500 USD extra}}")

    assert message =~ "unexpected tokens"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Cost.parse("{10 USD, oops extra}")

    assert message =~ "unexpected tokens"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Cost.parse("{{500 USD extra}}")

    assert message =~ "unexpected tokens"
  end
end
