defmodule Beancount.Directives.Custom do
  @moduledoc """
  The `custom` directive is a generic, user-defined directive.

  See [Custom](https://beancount.github.io/docs/beancount_language_syntax/#custom).

  ## Beancount syntax

      2026-01-01 custom "budget" Expenses:Food #monthly 400.00 USD

  General form: `YYYY-MM-DD custom "Type" Value...`

  ## Elixir struct

      %Beancount.Directives.Custom{
        date: ~D[2026-01-01],
        type: "budget",
        values: [
          Beancount.account_value("Expenses:Food"),
          Beancount.tag_value("monthly"),
          Beancount.amount_value(Decimal.new("400.00"), "USD")
        ],
        metadata: %{}
      }

  Or use `Beancount.custom/4`:

      Beancount.custom(~D[2026-01-01], "budget", [
        Beancount.account_value("Expenses:Food"),
        Beancount.tag_value("monthly"),
        Beancount.amount_value(Decimal.new("400.00"), "USD")
      ])

  Plain strings, `Decimal`, `Date`, booleans, and atoms are also valid `values`.

  ## Fields

    * `date` - `Date.t()` the custom entry applies to.
    * `type` - user-defined directive name (quoted in `.bean` text).
    * `values` - ordered list of scalars rendered after `type`. Use
      `Beancount.account_value/1`, `Beancount.tag_value/1`, and
      `Beancount.amount_value/2` for typed Beancount tokens.
    * `metadata` - optional map rendered below the directive.
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
