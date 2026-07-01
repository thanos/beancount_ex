if Code.ensure_loaded?(Explorer.DataFrame) do
  defmodule Beancount.Explorer do
    @moduledoc """
    Optional bridge from `Beancount.Query.Result` to `Explorer.DataFrame`.

    This module is only compiled when the optional
    [Explorer](https://hexdocs.pm/explorer) dependency is available. It lets
    query and report results flow into Explorer (and, via Explorer, render
    automatically as tables in Livebook).

    All columns are produced as strings; use Explorer's casting functions
    (e.g. `Explorer.DataFrame.mutate/2`) to coerce numeric columns as needed.
    """

    alias Beancount.Query.Result

    @doc """
    Convert a `Beancount.Query.Result` into an `Explorer.DataFrame`.

    Columns are preserved in order. An empty result yields an empty data frame.

    ## Examples

        result = %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Assets:Bank", "100 USD"]]
        }

        df = Beancount.Explorer.to_dataframe(result)
        Explorer.DataFrame.names(df)
        # => ["account", "balance"]

    """
    @spec to_dataframe(Result.t()) :: Explorer.DataFrame.t()
    def to_dataframe(%Result{columns: [], rows: _}) do
      Explorer.DataFrame.new([])
    end

    def to_dataframe(%Result{columns: columns, rows: rows}) do
      columns
      |> Enum.with_index()
      |> Enum.map(fn {name, index} ->
        {name, Enum.map(rows, fn row -> Enum.at(row, index) end)}
      end)
      |> Explorer.DataFrame.new()
    end
  end
end
