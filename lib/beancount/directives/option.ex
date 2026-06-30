defmodule Beancount.Directives.Option do
  @moduledoc """
  The `option` directive sets file-wide Beancount configuration.

      option "title" "My Ledger"
      option "operating_currency" "USD"
      option "infer_tolerance_from_cost" TRUE

  Common keys include `title`, `operating_currency`, `inferred_tolerance_default`,
  `inferred_tolerance_multiplier`, `infer_tolerance_from_cost`, and
  `tolerance_multiplier`.
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
