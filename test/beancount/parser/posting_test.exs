defmodule Beancount.Parser.PostingTest do
  use ExUnit.Case, async: true

  alias Beancount.Parser.Posting

  test "parse_line/1 parses flags, costs, and total prices" do
    assert {:ok, posting} = Posting.parse_line("  Assets:Bank  10 USD")
    assert posting.account == "Assets:Bank"
    assert Decimal.equal?(posting.amount, Decimal.new("10"))
    assert posting.currency == "USD"

    assert {:ok, posting} =
             Posting.parse_line("  ! Assets:Stocks  5 AAPL {10 USD} @@ 50 EUR")

    assert posting.flag == "!"
    assert posting.cost.per_amount == Decimal.new("10")
    assert posting.price.type == :total
    assert posting.price.currency == "EUR"

    assert {:ok, posting} = Posting.parse_line("  ? Assets:Bank  1 USD")
    assert posting.flag == "?"
  end

  test "parse_line/1 parses elided amounts, commodity-only postings, and unit prices" do
    assert {:ok, posting} = Posting.parse_line("  Expenses:Food")
    assert posting.amount == nil

    assert {:ok, posting} = Posting.parse_line("  Assets:Bank  10 USD @ 1.2 EUR")
    assert posting.price.type == :unit

    assert {:ok, posting} = Posting.parse_line("  Assets:Stocks  AAPL @ 10 USD")
    assert posting.currency == "AAPL"
    assert posting.amount == nil
    assert posting.price.amount == Decimal.new("10")
  end

  test "parse_line/1 parses amount without currency before a price annotation" do
    assert {:ok, posting} = Posting.parse_line("  Assets:Bank  10 @ 1.2 EUR")
    assert posting.amount == Decimal.new("10")
    assert posting.currency == nil
    assert posting.price.currency == "EUR"
  end

  test "parse_line/1 returns errors for invalid postings" do
    assert {:error, %Beancount.Parser.Error{message: message}} = Posting.parse_line("  ")
    assert message =~ "expected posting account"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Posting.parse_line("  Assets:Bank  oops USD")

    assert message =~ "invalid posting"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Posting.parse_line("  not-an-account  1 USD")

    assert message =~ "invalid posting account"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Posting.parse_line("  Assets:Bank {oops")

    assert message =~ "invalid posting token"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Posting.parse_line("  Assets:Bank  10 USD @ bad")

    assert message =~ "invalid price annotation"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Posting.parse_line("  Assets:Bank  10 USD extra")

    assert message =~ "unexpected trailing posting tokens"
  end
end
