defmodule Beancount.ExplorerTest do
  use ExUnit.Case, async: true

  alias Beancount.Query.Result

  @moduletag :explorer

  setup do
    unless Code.ensure_loaded?(Explorer.DataFrame) do
      flunk("Explorer not available; it is expected in the :test environment")
    end

    :ok
  end

  test "to_dataframe/1 builds a frame with the result's columns and rows" do
    result = %Result{
      columns: ["account", "balance"],
      rows: [["Assets:Bank", "5000 USD"], ["Income:Salary", "-5000 USD"]]
    }

    df = Beancount.Explorer.to_dataframe(result)

    assert Explorer.DataFrame.names(df) == ["account", "balance"]
    assert Explorer.DataFrame.n_rows(df) == 2
    assert df["account"] |> Explorer.Series.to_list() == ["Assets:Bank", "Income:Salary"]
  end

  test "to_dataframe/1 handles an empty result" do
    df = Beancount.Explorer.to_dataframe(%Result{columns: [], rows: []})
    assert Explorer.DataFrame.n_rows(df) == 0
  end
end
