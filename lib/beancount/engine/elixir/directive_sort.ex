defmodule Beancount.Engine.Elixir.DirectiveSort do
  @moduledoc false

  alias Beancount.Directives.{
    Balance,
    Close,
    Document,
    Include,
    Open,
    Option,
    Plugin,
    PopTag,
    PushTag
  }

  @sort_order %{
    Open => -2,
    Balance => -1,
    Document => 1,
    Close => 2
  }

  @undated_types MapSet.new([Option, Include, Plugin, PushTag, PopTag])

  @doc """
  Order directives for ledger processing.

  Undated directives (`option`, `include`, `plugin`, `pushtag`, `poptag`) stay in
  source-file order and run before dated entries. Dated entries are sorted by
  Beancount's `entry_sortkey`: date, directive-type priority, then line number.

  Uses ISO8601 date strings in the sort key because `%Date{}` does not implement
  correct `<=` ordering in Elixir.
  """
  @spec order([Beancount.Directive.t()]) :: [Beancount.Directive.t()]
  def order(directives) when is_list(directives) do
    {undated, _dated} = Enum.split_with(directives, &undated?/1)

    dated_sorted =
      directives
      |> Enum.with_index()
      |> Enum.reject(fn {directive, _index} -> undated?(directive) end)
      |> Enum.sort_by(&sort_key/1)
      |> Enum.map(&elem(&1, 0))

    undated ++ dated_sorted
  end

  defp undated?(%{__struct__: type}), do: MapSet.member?(@undated_types, type)
  defp undated?(directive), do: not Map.has_key?(directive, :date)

  defp sort_key({directive, index}) do
    line = Map.get(directive, :line, index + 1)

    {
      Date.to_iso8601(directive.date),
      Map.get(@sort_order, directive.__struct__, 0),
      line
    }
  end
end
