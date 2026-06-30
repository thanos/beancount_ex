defmodule Beancount.CostSpecTest do
  use ExUnit.Case, async: true

  alias Beancount.CostSpec

  test "normalize/1 accepts legacy cost maps" do
    assert %CostSpec{per_amount: amount, per_currency: "USD"} =
             CostSpec.normalize(%{amount: Decimal.new("10"), currency: "USD"})

    assert Decimal.equal?(amount, Decimal.new("10"))
  end

  test "to_string/1 per-unit cost" do
    spec = %CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}

    assert CostSpec.to_string(spec) == "{10 USD}"
  end

  test "to_string/1 total cost" do
    spec = %CostSpec{total_amount: Decimal.new("100"), total_currency: "USD"}

    assert CostSpec.to_string(spec) == "{{100 USD}}"
  end

  test "to_string/1 per and total cost" do
    spec = %CostSpec{
      per_amount: Decimal.new("502.12"),
      per_currency: "USD",
      total_amount: Decimal.new("9.95"),
      total_currency: "USD"
    }

    assert CostSpec.to_string(spec) == "{502.12 # 9.95 USD}"
  end

  test "to_string/1 cost with date" do
    spec = %CostSpec{
      per_amount: Decimal.new("10"),
      per_currency: "USD",
      date: ~D[2020-01-02]
    }

    assert CostSpec.to_string(spec) == "{10 USD, 2020-01-02}"
  end

  test "to_string/1 cost with label and merge" do
    spec = %CostSpec{
      per_amount: Decimal.new("10"),
      per_currency: "USD",
      label: "lot-a",
      merge: true
    }

    assert CostSpec.to_string(spec) == ~s({10 USD, "lot-a", merge})
  end

  test "to_string/1 date-only cost" do
    spec = %CostSpec{date: ~D[2020-01-01]}
    assert CostSpec.to_string(spec) == "{2020-01-01}"
  end

  test "to_string/1 label-only cost" do
    spec = %CostSpec{label: "magic lot"}
    assert CostSpec.to_string(spec) == ~s({"magic lot"})
  end

  test "to_string/1 raises for invalid cost spec" do
    assert_raise ArgumentError, fn -> CostSpec.to_string(%CostSpec{merge: true}) end
  end
end
