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
end
