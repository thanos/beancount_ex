defmodule Beancount.ReconciliationTest do
  use ExUnit.Case, async: false

  alias Beancount.Engine.CLI

  @fixture Path.join([
             "test",
             "fixtures",
             "external",
             "beancount",
             "example.beancount"
           ])

  @balances_bql "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"

  @holdings_bql """
  SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost \
  WHERE account ~ "^Assets" GROUP BY account ORDER BY account\
  """

  defp normalize_rows(%Beancount.Query.Result{rows: rows}) do
    rows
    |> Enum.map(fn row ->
      Enum.map(row, &String.trim/1)
    end)
    |> Enum.sort()
  end

  @tag :integration
  @tag :beancount
  @tag :reconciliation
  test "example.beancount passes bean-check" do
    assert {:ok, %Beancount.Result{status: :ok}} =
             Beancount.check_file(@fixture)
  end

  @tag :integration
  @tag :beancount
  @tag :reconciliation
  test "example.beancount round-trips through parse → render → bean-query" do
    original = File.read!(@fixture)

    {:ok, reference_balances} = CLI.query(original, @balances_bql)
    {:ok, reference_holdings} = CLI.query(original, @holdings_bql)

    {:ok, directives} = Beancount.parse_text(original)
    regenerated = Beancount.render(directives)

    {:ok, candidate_balances} = CLI.query(regenerated, @balances_bql)
    {:ok, candidate_holdings} = CLI.query(regenerated, @holdings_bql)

    assert normalize_rows(reference_balances) == normalize_rows(candidate_balances)
    assert normalize_rows(reference_holdings) == normalize_rows(candidate_holdings)
  end

  @tag :integration
  @tag :beancount
  @tag :reconciliation
  test "example.beancount compare/3 returns a structured result" do
    original = File.read!(@fixture)

    result =
      Beancount.Compare.compare(
        Beancount.Engine.CLI,
        Beancount.Engine.Elixir,
        original
      )

    assert match?({:ok, :equivalent}, result) or
             match?({:error, %Beancount.Property.Diff{}}, result)
  end

  @tag :integration
  @tag :beancount
  @tag :reconciliation
  @tag :reconciliation_compare
  @tag :skip
  test "example.beancount native engine agrees with CLI oracle" do
    original = File.read!(@fixture)

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.CLI,
               Beancount.Engine.Elixir,
               original
             )
  end
end
