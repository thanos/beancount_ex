defmodule Beancount.BQL.ParserTest do
  use ExUnit.Case, async: true

  alias Beancount.BQL.AST.{Column, Order, Query}

  test "parses balance query with GROUP BY and ORDER BY" do
    assert {:ok, %Query{select: select, group_by: group_by, order_by: order_by}} =
             Beancount.BQL.parse(
               "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
             )

    assert [%Column{as: "account"}, %Column{as: "balance"}] = select
    assert [{:ident, "account"}] = group_by
    assert [%Order{expr: {:ident, "account"}, direction: :asc}] = order_by
  end

  test "parses WHERE with regex match" do
    assert {:ok, %Query{where: where}} =
             Beancount.BQL.parse(
               "SELECT account, sum(position) AS balance WHERE account ~ \"^Assets\" GROUP BY account"
             )

    assert {:binary, :regex, {:ident, "account"}, {:string, "^Assets"}} = where
  end

  test "parses holdings query with units and cost" do
    assert {:ok, %Query{select: select}} =
             Beancount.BQL.parse(
               "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"
             )

    assert Enum.map(select, & &1.as) == ["account", "units", "cost"]
  end

  test "parses journal query" do
    assert {:ok, %Query{select: select, where: where}} =
             Beancount.BQL.parse(
               ~s(SELECT date, flag, payee, narration, position, balance WHERE account = "Assets:Bank" ORDER BY date)
             )

    assert length(select) == 6
    assert {:binary, :eq, {:ident, "account"}, {:string, "Assets:Bank"}} = where
  end

  test "rejects unknown functions" do
    assert {:error, {:bql, "unknown function not_supported"}} =
             Beancount.BQL.parse("SELECT not_supported()")
  end

  test "parses LIMIT and ORDER BY DESC" do
    assert {:ok, %Query{limit: 25, order_by: orders}} =
             Beancount.BQL.parse(
               "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account DESC LIMIT 25"
             )

    assert [%Order{direction: :desc}] = orders
  end

  test "parses ORDER BY ASC explicitly" do
    assert {:ok, %Query{order_by: [%Order{direction: :asc}]}} =
             Beancount.BQL.parse(
               "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account ASC"
             )
  end

  test "parses numeric and NOT expressions" do
    assert {:ok, %Query{where: where}} =
             Beancount.BQL.parse(
               "SELECT account WHERE NOT account = \"Assets:Bank\" GROUP BY account"
             )

    assert {:unary, :not, {:binary, :eq, {:ident, "account"}, {:string, "Assets:Bank"}}} = where

    assert {:ok, %Query{where: {:binary, :gt, {:ident, "amount"}, {:number, number}}}} =
             Beancount.BQL.parse("SELECT account WHERE amount > 100 GROUP BY account")

    assert Decimal.equal?(number, Decimal.new("100"))
  end

  test "parses comparison operators and count(*)" do
    assert {:ok, %Query{where: {:binary, :lte, _, _}}} =
             Beancount.BQL.parse("SELECT account WHERE amount <= 50 GROUP BY account")

    assert {:ok, %Query{where: {:binary, :neq, _, _}}} =
             Beancount.BQL.parse("SELECT account WHERE account != \"X\" GROUP BY account")

    assert {:ok, %Query{select: [%Column{expr: {:func, :count, [{:ident, "*"}]}}]}} =
             Beancount.BQL.parse("SELECT count(*)")
  end

  test "parses escaped strings and default function aliases" do
    assert {:ok, %Query{where: {:binary, :eq, _, {:string, string}}}} =
             Beancount.BQL.parse(~s(SELECT account WHERE account = "A\"B" GROUP BY account))

    assert string == ~s(A"B)

    assert {:ok, %Query{select: [%Column{as: "sum"}]}} =
             Beancount.BQL.parse("SELECT sum(position) GROUP BY account")
  end

  test "rejects invalid LIMIT and trailing input" do
    assert {:error, {:bql, "invalid LIMIT"}} =
             Beancount.BQL.parse("SELECT account LIMIT abc")

    assert {:error, {:bql, message}} =
             Beancount.BQL.parse("SELECT account GROUP BY account EXTRA")

    assert message =~ "invalid expression" or message =~ "unexpected trailing input"

    assert {:error, {:bql, "expected SELECT"}} =
             Beancount.BQL.parse("FROM account")

    assert {:error, {:bql, "empty expression"}} =
             Beancount.BQL.parse("SELECT account WHERE  GROUP BY account")

    assert {:error, {:bql, "invalid expression:" <> _}} =
             Beancount.BQL.parse("SELECT account WHERE !!! GROUP BY account")
  end

  test "parses remaining comparison operators and LIMIT with trailing space" do
    assert {:ok, %Query{where: {:binary, :gte, _, _}}} =
             Beancount.BQL.parse("SELECT account WHERE amount >= 50 GROUP BY account")

    assert {:ok, %Query{where: {:binary, :lt, _, _}}} =
             Beancount.BQL.parse("SELECT account WHERE amount < 50 GROUP BY account")

    assert {:ok, %Query{limit: 10}} =
             Beancount.BQL.parse("SELECT account GROUP BY account LIMIT 10 ")
  end

  test "parses SELECT with immediate WHERE clause split" do
    assert {:ok, %Query{where: where, group_by: group_by}} =
             Beancount.BQL.parse(
               "SELECT account, sum(position) AS balance WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"
             )

    assert {:binary, :regex, {:ident, "account"}, {:string, "^Assets"}} = where
    assert group_by == [{:ident, "account"}]
  end

  test "rejects malformed SELECT columns and ORDER BY expressions" do
    assert {:error, {:bql, "unknown function bad"}} =
             Beancount.BQL.parse("SELECT bad(col) GROUP BY account")

    assert {:error, {:bql, "invalid expression:" <> _}} =
             Beancount.BQL.parse("SELECT account GROUP BY account ORDER BY !!!")
  end

  test "parses WHERE without a following clause keyword" do
    assert {:ok, %Query{where: where, order_by: orders}} =
             Beancount.BQL.parse(
               ~s(SELECT account WHERE account = "Assets:Bank" ORDER BY account)
             )

    assert {:binary, :eq, {:ident, "account"}, {:string, "Assets:Bank"}} = where
    assert orders != []
  end

  test "parses WHERE as the final clause" do
    assert {:ok, %Query{where: where, group_by: group_by}} =
             Beancount.BQL.parse(~s(SELECT account WHERE account = "Assets:Bank"))

    assert {:binary, :eq, {:ident, "account"}, {:string, "Assets:Bank"}} = where
    assert group_by == []
  end

  test "parses journal column functions" do
    for name <- ["date", "flag", "payee", "narration", "position", "balance"] do
      assert {:ok, %Query{select: [%Column{expr: {:func, func, []}}]}} =
               Beancount.BQL.parse("SELECT #{name}() ORDER BY date")

      assert func == String.to_atom(name)
    end
  end

  test "parses LIMIT without trailing whitespace" do
    assert {:ok, %Query{limit: 10}} =
             Beancount.BQL.parse("SELECT account GROUP BY account LIMIT 10")
  end

  test "rejects trailing input after parsed clauses" do
    assert {:error, {:bql, message}} =
             Beancount.BQL.parse("SELECT account TRAILING")

    assert message =~ "invalid expression" or message =~ "unexpected trailing input"
  end
end
