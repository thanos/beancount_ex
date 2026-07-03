defmodule Beancount.ParserTest do
  use ExUnit.Case, async: true

  test "parse_text/1 parses a simple transaction" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -5000 USD
    """

    assert {:ok, directives} = Beancount.parse_text(text)
    assert length(directives) == 2
    assert [%Beancount.Directives.Open{}, %Beancount.Directives.Transaction{}] = directives
  end

  test "parse/1 passes directive lists through" do
    directive = Beancount.commodity(~D[2026-01-01], "USD")
    assert {:ok, [^directive]} = Beancount.parse([directive])
  end

  test "parse!/1 raises on invalid input" do
    assert_raise Beancount.Parser.Error, fn ->
      Beancount.parse!("not a directive")
    end
  end

  test "parse_text/1 returns structured errors" do
    assert {:error, %Beancount.Parser.Error{message: message, line: line}} =
             Beancount.parse_text("2026-01-01 open")

    assert is_binary(message)
    assert is_integer(line)
  end

  test "parse_text/1 returns structured error for invalid calendar dates" do
    assert {:error, %Beancount.Parser.Error{message: message, line: 1}} =
             Beancount.parse_text("2026-02-30 open Assets:Bank USD\n")

    assert message =~ "invalid date"
  end

  test "parse_text/1 parses query, plugin, and tag directives" do
    text = """
    2026-01-01 query "balances" "SELECT account"
    plugin "beancount.plugins.auto_accounts"
    pushtag #trip
    poptag #trip
    """

    assert {:ok,
            [
              %Beancount.Directives.Query{name: "balances"},
              %Beancount.Directives.Plugin{},
              %Beancount.Directives.PushTag{tag: "trip"},
              %Beancount.Directives.PopTag{tag: "trip"}
            ]} = Beancount.parse_text(text)
  end

  test "public constructors build new directive types" do
    assert %Beancount.Directives.Query{} =
             Beancount.query_directive(~D[2026-01-01], "balances", "SELECT account")

    assert %Beancount.Directives.Plugin{} = Beancount.plugin("mod")
    assert %Beancount.Directives.PushTag{} = Beancount.push_tag("trip")
    assert %Beancount.Directives.PopTag{} = Beancount.pop_tag("trip")
  end

  test "parse_file/1 reads a ledger from disk" do
    path = Path.join(System.tmp_dir!(), "parser_#{System.unique_integer([:positive])}.bean")
    File.write!(path, "2026-01-01 commodity USD\n")

    on_exit(fn -> File.rm(path) end)

    assert {:ok, [%Beancount.Directives.Commodity{currency: "USD"}]} = Beancount.parse_file(path)
    assert {:error, :enoent} = Beancount.parse_file(path <> ".missing")
  end

  test "parse_text/1 covers pad, include, option, balance tolerance, and rich postings" do
    text = """
    include "accounts.bean"
    option "title" "Example"
    option "operating_currency" "USD"

    2026-01-01 open Assets:Bank USD
    2026-01-01 open Assets:Stocks "FIFO"
    2026-01-01 open Equity:Opening

    2026-01-02 pad Assets:Bank Equity:Opening

    2026-01-03 balance Assets:Bank  100 ~ 0.5 USD

    2026-01-04 txn "Shop" "Buy stock"
      Assets:Stocks  10 AAPL {150 USD, 2020-01-01} @ 155 USD
      Assets:Bank  -1550 USD
    """

    assert {:ok, directives} = Beancount.parse_text(text)
    assert Enum.any?(directives, &match?(%Beancount.Directives.Include{}, &1))
    assert Enum.any?(directives, &match?(%Beancount.Directives.Pad{}, &1))

    assert Enum.any?(
             directives,
             &match?(%Beancount.Directives.Balance{tolerance: %Decimal{}}, &1)
           )

    [%Beancount.Directives.Transaction{postings: postings} | _] =
      Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))

    assert Enum.any?(postings, &(&1.cost != nil and &1.price != nil))
  end

  test "parse_text/1 parses plugin config and transaction metadata" do
    text = """
    plugin "beancount.plugins.auto_accounts" "Assets:Cash"

    2026-01-01 open Assets:Bank USD

    2026-01-02 * "Payee" "Narration"
      source: "email"
      imported: TRUE
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:ok, directives} = Beancount.parse_text(text)

    assert [%Beancount.Directives.Plugin{config: "Assets:Cash"} | _] = directives

    [%Beancount.Directives.Transaction{metadata: metadata} | _] =
      Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))

    assert metadata["source"] == "email"
    assert metadata["imported"] == true
  end

  test "parse/1 parses text binaries through parse_text" do
    assert {:ok, [%Beancount.Directives.Commodity{}]} =
             Beancount.parse("2026-01-01 commodity USD\n")
  end

  test "parse_text/1 parses elided and commodity-only postings" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Expenses:Food USD

    2026-01-02 * "Shop" "Snack"
      Expenses:Food
      Assets:Bank  -5 USD

    2026-01-03 * "FX" "Rate"
      Assets:Bank  10 USD @ 1.2 EUR
      Expenses:Food  -12 EUR
    """

    assert {:ok, directives} = Beancount.parse_text(text)

    txns = Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))
    assert length(txns) == 2

    [%Beancount.Directives.Transaction{postings: elided_postings} | _] = txns
    assert Enum.any?(elided_postings, &is_nil(&1.amount))

    [%Beancount.Directives.Transaction{postings: priced_postings} | _] = Enum.reverse(txns)
    assert Enum.any?(priced_postings, &(&1.price != nil))
  end
end
