defmodule Beancount.BQL.ASTTest do
  use ExUnit.Case, async: true

  alias Beancount.BQL.AST.{Column, Order, Query}

  test "builds query and column structs used by the parser" do
    column = %Column{expr: {:ident, "account"}, as: "account"}
    order = %Order{expr: {:ident, "date"}, direction: :desc}

    query = %Query{
      select: [column],
      where: {:binary, :eq, {:ident, "account"}, {:string, "Assets:Bank"}},
      group_by: [{:ident, "account"}],
      order_by: [order],
      limit: 10
    }

    assert query.limit == 10
    assert query.where == {:binary, :eq, {:ident, "account"}, {:string, "Assets:Bank"}}
    assert [%Order{direction: :desc}] = query.order_by
  end
end
