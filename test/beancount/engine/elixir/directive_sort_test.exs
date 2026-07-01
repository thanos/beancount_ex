defmodule Beancount.Engine.Elixir.DirectiveSortTest do
  use ExUnit.Case, async: true

  alias Beancount.Directives.Transaction
  alias Beancount.Engine.Elixir.{DirectiveSort, Ledger}

  @tag :reconciliation
  test "orders dated directives by date, not file order" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Income:Salary USD
    2026-01-01 open Equity:Opening USD

    2026-01-01 * "Opening"
      Assets:Bank                         100 USD
      Equity:Opening                     -100 USD

    2026-01-10 balance Assets:Bank         150 USD

    2026-01-03 * "Payroll"
      Assets:Bank                          50 USD
      Income:Salary                       -50 USD
    """

    {:ok, directives} = Beancount.parse_text(text)

    ordered = DirectiveSort.order(directives)

    payroll_index = Enum.find_index(ordered, &match?(%Transaction{narration: "Payroll"}, &1))
    balance_index = Enum.find_index(ordered, &match?(%Beancount.Directives.Balance{}, &1))

    assert payroll_index < balance_index

    ledger = directives |> Ledger.new() |> Ledger.process(directives)
    assert Ledger.errors(ledger) == []
  end

  test "balance directives sort before same-day transactions" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Expenses:Fees USD
    2026-01-01 open Equity:Opening USD

    2026-01-05 * "Spend"
      Assets:Bank                          -10 USD
      Expenses:Fees                         10 USD

    2026-01-05 balance Assets:Bank         100 USD

    2026-01-01 * "Opening"
      Assets:Bank                         100 USD
      Equity:Opening                     -100 USD
    """

    {:ok, directives} = Beancount.parse_text(text)
    ledger = directives |> Ledger.new() |> Ledger.process(directives)
    assert Ledger.errors(ledger) == []
  end

  test "option directives stay before dated entries" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-01 * "Opening"
      Assets:Bank                         100 USD
      Equity:Opening                     -100 USD

    option "inferred_tolerance_default" "0.01"

    2026-01-02 balance Assets:Bank        100.005 USD
    """

    {:ok, directives} = Beancount.parse_text(text)
    ordered = DirectiveSort.order(directives)

    assert [%Beancount.Directives.Option{} | _] = ordered
    assert Ledger.errors(Ledger.process(Ledger.new(), directives)) == []
  end

  test "pushtag stays at file position among date-sorted entries" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Income:Salary USD
    2026-01-01 open Equity:Opening USD

    2026-01-01 * "Opening"
      Assets:Bank                         100 USD
      Equity:Opening                     -100 USD

    2026-01-10 balance Assets:Bank         150 USD

    pushtag #trip

    2026-01-03 * "Payroll"
      Assets:Bank                          50 USD
      Income:Salary                       -50 USD
    """

    {:ok, directives} = Beancount.parse_text(text)
    ordered = DirectiveSort.order(directives)

    indices =
      for {d, i} <- Enum.with_index(ordered),
          match?(%Beancount.Directives.Balance{}, d) or
            match?(%Beancount.Directives.PushTag{}, d) or
            match?(%Transaction{narration: "Payroll"}, d),
          do: {d, i}

    balance_idx =
      elem(Enum.find(indices, fn {d, _} -> match?(%Beancount.Directives.Balance{}, d) end), 1)

    pushtag_idx =
      elem(Enum.find(indices, fn {d, _} -> match?(%Beancount.Directives.PushTag{}, d) end), 1)

    payroll_idx = elem(Enum.find(indices, fn {d, _} -> match?(%Transaction{}, d) end), 1)

    assert pushtag_idx < payroll_idx
    assert payroll_idx < balance_idx
  end
end
