defmodule Beancount.Directives.Option do
  @moduledoc """
  The `option` directive sets file-wide Beancount configuration.

  See [Options](https://beancount.github.io/docs/beancount_language_syntax/#options).

  ## Beancount syntax

      option "title" "My Ledger"
      option "operating_currency" "USD"
      option "infer_tolerance_from_cost" TRUE

  General form: `option "Name" Value`

  This directive has no date.

  ## Elixir struct

      %Beancount.Directives.Option{
        name: "operating_currency",
        value: "USD"
      }

      %Beancount.Directives.Option{
        name: "infer_tolerance_from_cost",
        value: true
      }

  Or use `Beancount.option/2`:

      Beancount.option("operating_currency", "USD")
      Beancount.option("infer_tolerance_from_cost", true)

  ## Fields

    * `name` - option key string. Common values: `"title"`, `"operating_currency"`,
      `"inferred_tolerance_default"`, `"inferred_tolerance_multiplier"`,
      `"infer_tolerance_from_cost"`, `"tolerance_multiplier"`.
    * `value` - option value: binary, boolean (`true`/`false` rendered as
      `TRUE`/`FALSE`), `Decimal`, `Date`, or atom.
  """

  alias Beancount.Renderer

  @enforce_keys [:name, :value]
  defstruct name: nil, value: nil

  @type t :: %__MODULE__{name: String.t(), value: term()}

  defimpl Beancount.Directive do
    def to_bean(%{name: name, value: value}) do
      "option " <> Renderer.quote_string(name) <> " " <> Renderer.format_value(value)
    end
  end
end
