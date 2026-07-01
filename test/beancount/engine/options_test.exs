defmodule Beancount.Engine.Elixir.OptionsTest do
  use ExUnit.Case, async: true

  alias Beancount.Directives.Option
  alias Beancount.Engine.Elixir.Options

  defp option(name, value), do: %Option{name: name, value: value}

  test "new/0 returns default options" do
    assert %Options{
             operating_currency: nil,
             inferred_tolerance_default: nil,
             infer_tolerance_from_cost: false
           } = Options.new()
  end

  test "apply/2 sets operating_currency" do
    {options, errors} = Options.apply(Options.new(), option("operating_currency", "USD"))
    assert errors == []
    assert options.operating_currency == "USD"
  end

  test "apply/2 parses inferred_tolerance_default" do
    {options, errors} =
      Options.apply(Options.new(), option("inferred_tolerance_default", "0.005 USD"))

    assert errors == []
    assert Decimal.equal?(options.inferred_tolerance_default, Decimal.new("0.005"))
  end

  test "apply/2 rejects invalid inferred_tolerance_default values" do
    {_options, errors} =
      Options.apply(Options.new(), option("inferred_tolerance_default", "not-a-number"))

    assert [%{message: message}] = errors
    assert message =~ "inferred_tolerance_default"
  end

  test "apply/2 parses inferred_tolerance_multiplier from strings and decimals" do
    {options, errors} =
      Options.apply(Options.new(), option("inferred_tolerance_multiplier", "2.5"))

    assert errors == []
    assert Decimal.equal?(options.inferred_tolerance_multiplier, Decimal.new("2.5"))

    {options, errors} =
      Options.apply(Options.new(), option("inferred_tolerance_multiplier", Decimal.new("3")))

    assert errors == []
    assert Decimal.equal?(options.inferred_tolerance_multiplier, Decimal.new("3"))
  end

  test "apply/2 rejects invalid inferred_tolerance_multiplier" do
    {_options, errors} =
      Options.apply(Options.new(), option("inferred_tolerance_multiplier", "not-a-number"))

    assert [%{message: message}] = errors
    assert message =~ "inferred_tolerance_multiplier"
  end

  test "apply/2 parses infer_tolerance_from_cost booleans" do
    {options, errors} =
      Options.apply(Options.new(), option("infer_tolerance_from_cost", "TRUE"))

    assert errors == []
    assert options.infer_tolerance_from_cost

    {options, errors} =
      Options.apply(Options.new(), option("infer_tolerance_from_cost", "FALSE"))

    assert errors == []
    refute options.infer_tolerance_from_cost
  end

  test "apply/2 rejects non-string infer_tolerance_from_cost values" do
    {_options, errors} =
      Options.apply(Options.new(), option("infer_tolerance_from_cost", true))

    assert [%{message: message}] = errors
    assert message =~ "unexpected BOOL"
  end

  test "apply/2 parses tolerance_multiplier" do
    {options, errors} = Options.apply(Options.new(), option("tolerance_multiplier", "1.5"))
    assert errors == []
    assert Decimal.equal?(options.tolerance_multiplier, Decimal.new("1.5"))

    {options, errors} =
      Options.apply(Options.new(), option("tolerance_multiplier", Decimal.new("2")))

    assert errors == []
    assert Decimal.equal?(options.tolerance_multiplier, Decimal.new("2"))
  end

  test "apply/2 rejects invalid tolerance_multiplier" do
    {_options, errors} =
      Options.apply(Options.new(), option("tolerance_multiplier", "not-a-number"))

    assert [%{message: message}] = errors
    assert message =~ "tolerance_multiplier"
  end

  test "apply/2 rejects non-string inferred_tolerance_default values" do
    {_options, errors} =
      Options.apply(Options.new(), option("inferred_tolerance_default", true))

    assert [%{message: message}] = errors
    assert message =~ "inferred_tolerance_default"
  end

  test "apply/2 rejects invalid infer_tolerance_from_cost strings" do
    {_options, errors} =
      Options.apply(Options.new(), option("infer_tolerance_from_cost", "MAYBE"))

    assert [%{message: message}] = errors
    assert message =~ "syntax error"
  end

  test "apply/2 ignores title and unknown options" do
    options = Options.new()

    {unchanged, errors} = Options.apply(options, option("title", "Example"))
    assert errors == []
    assert unchanged == options

    {unchanged, errors} = Options.apply(options, option("unknown_option", "value"))
    assert errors == []
    assert unchanged == options
  end
end
