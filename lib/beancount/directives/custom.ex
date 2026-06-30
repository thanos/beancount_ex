defmodule Beancount.Directives.Custom do
  @moduledoc """
  The `custom` directive is a generic, user-defined directive.

      2026-01-01 custom "budget" Expenses:Food "monthly" 400.00 USD

  `values` is a list of scalars rendered in order. Use `Beancount.account_value/1`,
  `Beancount.tag_value/1`, and `Beancount.amount_value/2` for account, tag, and
  amount values; plain strings, `Decimal`, `Date`, booleans, and atoms are also
  supported.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :type]
  defstruct date: nil, type: nil, values: [], metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          type: String.t(),
          values: [term()],
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, type: type, values: values} = custom) do
      header =
        [Renderer.format_date(date), "custom", Renderer.quote_string(type)]
        |> Enum.join(" ")
        |> append_values(values)

      Renderer.lines_to_fragment([header | Renderer.render_metadata(custom.metadata)])
    end

    defp append_values(header, []), do: header

    defp append_values(header, values) do
      header <> " " <> Enum.map_join(values, " ", &Renderer.format_value/1)
    end
  end
end
