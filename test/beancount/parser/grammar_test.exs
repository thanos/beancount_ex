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

  test "parse/1 attaches posting-level metadata" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "Shop" "Purchase"
      Assets:Bank  1 USD
        ref: "abc"
      Equity:Opening  -1 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    [%Beancount.Directives.Transaction{postings: postings}] =
      Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))

    [bank, equity] = postings
    assert bank.metadata == %{"ref" => "abc"}
    assert equity.metadata == %{}
  end

  test "parse/1 treats capitalised metadata keys as metadata" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "Shop" "Purchase"
      Foo: "value"
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    [%Beancount.Directives.Transaction{metadata: metadata}] =
      Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))

    assert metadata == %{"Foo" => "value"}
  end

  test "parse/1 parses undated include, option, plugin, and tag directives" do
    text = """
    include "extra.bean"
    option "title" "Example"
    plugin "beancount.plugins.module"

    pushtag #trip
    poptag #trip

    2026-01-01 open Assets:Bank USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Include{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Include{}, &1))

    assert [%Beancount.Directives.Option{name: "title"} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Option{}, &1))

    assert [%Beancount.Directives.Plugin{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Plugin{}, &1))

    assert [%Beancount.Directives.PushTag{tag: "trip"} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.PushTag{}, &1))

    assert [%Beancount.Directives.PopTag{tag: "trip"} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.PopTag{}, &1))
  end

  test "parse/1 parses price, note, event, pad, and query directives" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-02 price USD 1.25 EUR
    2026-01-03 note Assets:Bank "Remember"
    2026-01-04 event "employer" "Acme"
    2026-01-05 pad Assets:Bank Equity:Opening
    2026-01-06 query "beancount" "SELECT account"
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Price{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Price{}, &1))

    assert [%Beancount.Directives.Note{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Note{}, &1))

    assert [%Beancount.Directives.Event{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Event{}, &1))

    assert [%Beancount.Directives.Pad{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Pad{}, &1))

    assert [%Beancount.Directives.Query{} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Query{}, &1))
  end

  test "parse/1 parses balance tolerance and open booking-only tail" do
    text = """
    2026-01-01 open Assets:Stocks AAPL "FIFO"
    2026-01-02 balance Assets:Bank  100 ~ 0.01 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Open{booking: "FIFO"} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Open{}, &1))

    assert [%Beancount.Directives.Balance{tolerance: tolerance} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Balance{}, &1))

    assert Decimal.equal?(tolerance, Decimal.new("0.01"))
  end

  test "parse/1 skips org-mode headers" do
    text = """
    * Section
    ** Subsection
    2026-01-01 commodity USD
    """

    assert {:ok, [%Beancount.Directives.Commodity{}]} = Grammar.parse(text)
  end

  test "parse/1 parses plugin with config and multiline query" do
    text = """
    plugin "beancount.plugins.module" "config"

    2026-01-01 open Assets:Bank USD

    2026-01-02 query "beancount" "
    SELECT account
    "
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Plugin{config: "config"} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Plugin{}, &1))

    assert [%Beancount.Directives.Query{bql: bql} | _] =
             Enum.filter(directives, &match?(%Beancount.Directives.Query{}, &1))

    assert bql =~ "SELECT account"
  end

  test "parse/1 parses custom directive with account and amount values" do
    text = """
    2026-01-01 custom "ping" Assets:Bank 42 USD
    """

    assert {:ok, [%Beancount.Directives.Custom{values: values}]} = Grammar.parse(text)
    assert Enum.any?(values, &(&1 == "Assets:Bank"))
    assert Enum.any?(values, &(&1 == "USD"))
    assert Enum.any?(values, &match?(%Decimal{}, &1))
  end

  test "parse/1 parses txn flag transactions and stops at comments" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 txn "Payee" "Narration"
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    ; comment ends transaction body
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Transaction{flag: "txn"}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))
  end

  test "parse/1 returns errors for invalid undated and dated directives" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("pushtag trip")

    assert message =~ "expected tag"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 open Assets:Bank USD EUR EXTRA")

    assert message =~ "invalid open"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 query only-one-token")

    assert message =~ "invalid query"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 pad Assets:Bank")

    assert message =~ "invalid pad"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 note Assets:Bank unquoted")

    assert message =~ "expected quoted string"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 custom \"x\" notanumber")

    assert message =~ "invalid number"
  end

  test "parse/1 returns errors for invalid commodity and balance directives" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 balance Assets:Bank")

    assert message =~ "invalid balance"
  end

  test "parse/1 returns error for unknown dated directive kind" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 commodity")

    assert message =~ "unknown dated directive"
  end

  test "parse/1 returns error for unterminated multiline query" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-02 query "beancount" "
    SELECT account
    """

    assert {:error, %Beancount.Parser.Error{message: message}} = Grammar.parse(text)
    assert message =~ "unterminated query string"
  end

  test "parse/1 returns errors for malformed dated directives and headers" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("bad-date open Assets:Bank USD")

    assert message =~ "expected directive"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 commodity BAD!")

    assert message =~ "invalid commodity"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 note Assets:Bank")

    assert message =~ "expected quoted string"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 document Assets:Bank")

    assert message =~ "expected quoted string"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse(~s(2026-01-01 event "type"))

    assert message =~ "expected quoted string"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 open not-an-account USD")

    assert message =~ "invalid account"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse(~s(2026-01-01 note Assets:Bank "unclosed))

    assert message =~ "expected quoted string"
  end

  test "parse/1 parses transaction with empty payee and narration header" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * ""
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Transaction{payee: nil, narration: ""}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))
  end

  test "parse/1 parses transaction with narration-only header" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "Only narration"
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Transaction{payee: nil, narration: "Only narration"}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))
  end

  test "parse/1 returns invalid transaction header with too many tokens" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "Payee" "Narration" "Extra"
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:error, %Beancount.Parser.Error{message: message}} = Grammar.parse(text)
    assert message =~ "invalid transaction header"
  end

  test "parse/1 returns invalid price and balance amount directives" do
    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 price USD")

    assert message =~ "invalid price"

    assert {:error, %Beancount.Parser.Error{message: message}} =
             Grammar.parse("2026-01-01 balance Assets:Bank 100")

    assert message =~ "invalid balance amount"
  end

  test "parse/1 parses multiline query closed on the same line" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-02 query "beancount" "
    SELECT account"
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Query{bql: bql}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Query{}, &1))

    assert bql =~ "SELECT account"
  end

  test "parse/1 parses custom amount token and posting metadata" do
    text = """
    2026-01-01 custom "ping" 10 USD

    2026-01-02 open Assets:Bank USD
    2026-01-03 * "Payee" "Narration"
      Assets:Bank  1 USD
        memo: "saved"
    """

    assert {:ok, directives} = Grammar.parse(text)

    assert [%Beancount.Directives.Custom{values: values}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Custom{}, &1))

    assert Enum.any?(values, &match?(%Decimal{}, &1))
    assert "USD" in values

    assert [%Beancount.Directives.Transaction{postings: [%{metadata: %{"memo" => "saved"}} | _]}] =
             Enum.filter(directives, &match?(%Beancount.Directives.Transaction{}, &1))
  end

  test "parse/1 returns posting parse errors inside transactions" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-02 * "Payee"
      not-a-posting
    """

    assert {:error, %Beancount.Parser.Error{}} = Grammar.parse(text)
  end

  test "parse/1 returns transaction header errors" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-02 * Payee unquoted
      Assets:Bank  1 USD
    """

    assert {:error, %Beancount.Parser.Error{message: message}} = Grammar.parse(text)
    assert message =~ "expected quoted string"
  end
end
