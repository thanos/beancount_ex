defmodule Beancount.Parser.LexerTest do
  use ExUnit.Case, async: true

  alias Beancount.Parser.Lexer

  test "parse_account/1 and parse_commodity/1 extract tokens" do
    assert {:ok, "Assets:Bank", ""} = Lexer.parse_account("Assets:Bank")
    assert {:ok, "USD", " remainder"} = Lexer.parse_commodity("USD remainder")
  end

  test "parse_number/1 parses decimals and rejects invalid input" do
    assert {:ok, amount, ""} = Lexer.parse_number("-12.50")
    assert Decimal.equal?(amount, Decimal.new("-12.50"))
    assert {:error, false, "nope", 0, 1, []} = Lexer.parse_number("nope")
  end

  test "parse_boolean/1 parses TRUE and FALSE" do
    assert {:ok, value, ""} = Lexer.parse_boolean("TRUE")
    assert value == true or value == [true]

    assert {:ok, value, ""} = Lexer.parse_boolean("FALSE")
    assert value == false or value == [false]
  end

  test "split_tokens/1 preserves quoted strings" do
    assert ["2026-01-01", "open", "Assets:Bank", "USD"] =
             Lexer.split_tokens("2026-01-01 open Assets:Bank USD")

    assert [~s("hello world"), "USD"] = Lexer.split_tokens(~s("hello world" USD))
  end
end
