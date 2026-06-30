defmodule Beancount.Parser.MetadataTest do
  use ExUnit.Case, async: true

  alias Beancount.Parser.Metadata
  alias Beancount.Value

  test "parse_value/1 parses booleans, dates, tags, and amounts" do
    assert {:ok, true} = Metadata.parse_value("TRUE")
    assert {:ok, false} = Metadata.parse_value("FALSE")
    assert {:ok, ~D[2026-01-01]} = Metadata.parse_value("2026-01-01")
    assert {:ok, %Value.Tag{name: "trip"}} = Metadata.parse_value("#trip")
    assert {:ok, %Value.Amount{number: amount, currency: "USD"}} = Metadata.parse_value("42 USD")
    assert Decimal.equal?(amount, Decimal.new("42"))
  end

  test "parse_value/1 parses quoted strings and bare strings" do
    assert {:ok, "hello"} = Metadata.parse_value(~s("hello"))
    assert {:ok, "plain"} = Metadata.parse_value("plain")
  end

  test "parse_line/1 parses key-value metadata" do
    assert {:ok, {"source", "scan"}} = Metadata.parse_line("  source: \"scan\"")
  end

  test "parse_line/1 returns an error for invalid lines" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Metadata.parse_line("not-metadata", line: 4)

    assert message =~ "invalid metadata"
  end

  test "parse_value/1 returns an error for invalid quoted values" do
    assert {:error, %Beancount.Parser.Error{}} = Metadata.parse_value(~s("unclosed))
  end

  test "parse_value/1 returns an error for invalid amount metadata" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Metadata.parse_value("oops USD")

    assert message =~ "invalid numeric metadata value"
  end
end
