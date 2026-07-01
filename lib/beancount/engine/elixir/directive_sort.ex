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

  @config_undated_modules [Option, Include, Plugin]
  @positional_undated_modules [PushTag, PopTag]

  @doc """
  Order directives for ledger processing.

  Configuration directives (`option`, `include`, `plugin`) run first in file order.
  `pushtag` / `poptag` keep their source-file positions relative to dated entries.
  Remaining dated directives sort by Beancount's `entry_sortkey`: date, directive
  type, then file index.

  Uses ISO8601 date strings in the sort key because `%Date{}` does not implement
  correct `<=` ordering in Elixir.
  """
  @spec order([Beancount.Directive.t()]) :: [Beancount.Directive.t()]
  def order(directives) when is_list(directives) do
    indexed = Enum.with_index(directives)

    {config, rest} =
      Enum.split_with(indexed, fn {directive, _index} -> config_undated?(directive) end)

    {positional, dated} =
      Enum.split_with(rest, fn {directive, _index} -> positional_undated?(directive) end)

    dated_sorted =
      dated
      |> Enum.sort_by(fn {directive, index} -> dated_sort_key(directive, index) end)

    config
    |> Enum.map(&elem(&1, 0))
    |> Kernel.++(merge_by_file_index(positional, dated_sorted))
  end

  defp config_undated?(%{__struct__: type})
       when type in @config_undated_modules,
       do: true

  defp config_undated?(_), do: false

  defp positional_undated?(%{__struct__: type})
       when type in @positional_undated_modules,
       do: true

  defp positional_undated?(_), do: false

  defp dated_sort_key(directive, index) do
    line = Map.get(directive, :line, index + 1)

    {
      Date.to_iso8601(directive.date),
      Map.get(@sort_order, directive.__struct__, 0),
      line
    }
  end

  defp merge_by_file_index([], dated), do: Enum.map(dated, &elem(&1, 0))

  defp merge_by_file_index(positional, []), do: Enum.map(positional, &elem(&1, 0))

  defp merge_by_file_index([{directive, index} | positional_rest], dated) do
    {before, after_list} = Enum.split_while(dated, fn {_, dated_index} -> dated_index < index end)

    Enum.map(before, &elem(&1, 0)) ++
      [directive | merge_by_file_index(positional_rest, after_list)]
  end
end
