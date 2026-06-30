defmodule Beancount.Parser.GrammarTest do
  use ExUnit.Case, async: true

  alias Beancount.Parser.Grammar

  for case_dir <- Beancount.Golden.cases() do
    @case_dir case_dir
    @name Path.basename(case_dir)

    test "parses golden expected.bean for #{@name}" do
      bean = Beancount.Golden.expected_bean(@case_dir)
      assert {:ok, directives} = Grammar.parse(bean)
      assert directives != []
    end
  end

  test "parse/1 skips blank lines and comments" do
    text = """
    ; header comment

    2026-01-01 commodity USD

    ; trailing
    """

    assert {:ok, [%Beancount.Directives.Commodity{}]} = Grammar.parse(text)
  end

  test "parse/1 parses transactions with tags, links, and narration-only headers" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "Narration only" #trip ^link-1
      Assets:Bank  1 USD
      Equity:Opening  -1 USD

    2026-01-03 txn "Payee only"
      Assets:Bank  2 USD
      Equity:Opening  -2 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    [%Beancount.Directives.Transaction{tags: tags, links: links, payee: nil} | _] =
      Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))

    assert "trip" in tags
    assert "link-1" in links
  end

  test "parse/1 parses custom values, close metadata, and open booking" do
    text = """
    2026-01-01 open Assets:Stocks AAPL "STRICT"
    2026-01-01 open Assets:Bank USD,EUR

    2026-01-02 custom "budget" Expenses:Food #trip 400 USD

    2026-12-31 close Assets:Bank
      closed: TRUE
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Open{booking: "STRICT"} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Open{}, &1))

    assert [%Beancount.Directives.Custom{values: values} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Custom{}, &1))

    assert length(values) == 4

    assert [%Beancount.Directives.Close{metadata: %{"closed" => true}} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Close{}, &1))
  end

  test "parse/1 parses option booleans and document directives" do
    text = """
    option "infer_tolerance_from_cost" FALSE
    2026-01-01 open Assets:Bank USD
    2026-01-02 document Assets:Bank "statement.pdf"
      source: "mail"
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Option{value: false} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Option{}, &1))

    assert [%Beancount.Directives.Document{metadata: %{"source" => "mail"}} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Document{}, &1))
  end

  test "parse/1 returns structured errors for invalid input" do
    assert {:error, %Beancount.Parser.Error{message: message}} = Grammar.parse("not a directive")
    assert message =~ "expected directive"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 unknown")

    assert message =~ "unknown dated directive"

    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("pushtag trip")

    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("plugin")

    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("2026-01-01 balance Assets:Bank")

    assert {:error, %Beancount.Parser.Error{}} =
             Grammar.parse("2026-01-01 price USD")

    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("2026-01-01 note Assets:Bank")

    assert {:error, %Beancount.Parser.Error{}} =
             Grammar.parse("2026-01-01 query \"only-one\"")

    assert {:error, %Beancount.Parser.Error{}} =
             Grammar.parse("2026-01-01 open")

    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("2026-01-01 pad")
    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("2026-01-01 event")
    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("2026-01-01 document")
    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("2026-01-01 custom")
    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("include unquoted.bean")
    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse("option only-name")

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse(~s'2026-01-01 * "too" "many" "tokens"')

    assert message =~ "invalid transaction header"
  end

  test "parse/1 parses custom values with dates and bare numbers" do
    text = """
    2026-01-01 custom "ping" 2026-01-01 42 FALSE
    """

    assert {:ok, [%Beancount.Directives.Custom{values: values}]} = Grammar.parse(text)
    assert length(values) == 3
    assert Enum.any?(values, &match?(%Date{}, &1))
    assert Enum.any?(values, &(&1 == false))
  end

  test "parse/1 parses payee and narration transaction headers" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "Payee" "Narration"
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Transaction{payee: "Payee", narration: "Narration"}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))
  end
end
