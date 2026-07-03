defmodule Beancount.Engine.Elixir.ToleranceTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.{Options, Tolerance}

  test "infer/3 uses half-unit tolerance for integer amounts" do
    options = %Options{inferred_tolerance_default: nil}

    tolerance = Tolerance.infer(options, "USD", [Decimal.new("100")])

    assert Decimal.equal?(tolerance, Decimal.new("0.5"))
  end

  test "infer/3 scales tolerance by decimal precision" do
    options = %Options{inferred_tolerance_default: nil}

    tolerance = Tolerance.infer(options, "USD", [Decimal.new("100.01")])

    assert Decimal.equal?(tolerance, Decimal.new("0.005"))
  end

  test "infer/3 applies configured multipliers and defaults" do
    options = %Options{
      inferred_tolerance_default: Decimal.new("0.01"),
      inferred_tolerance_multiplier: Decimal.new("2"),
      tolerance_multiplier: Decimal.new("3")
    }

    tolerance = Tolerance.infer(options, "USD", [])

    assert Decimal.equal?(tolerance, Decimal.new("0.06"))
  end

  test "infer/3 chooses the maximum precision tolerance across amounts" do
    options = %Options{inferred_tolerance_default: nil}

    tolerance =
      Tolerance.infer(options, "USD", [Decimal.new("100"), Decimal.new("0.01")])

    assert Decimal.equal?(tolerance, Decimal.new("0.5"))
  end

  test "within?/3 compares actual and expected within tolerance" do
    assert Tolerance.within?(Decimal.new("100.004"), Decimal.new("100"), Decimal.new("0.005"))
    refute Tolerance.within?(Decimal.new("100.02"), Decimal.new("100"), Decimal.new("0.005"))
  end
end
