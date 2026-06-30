defmodule Beancount.Directives.Posting do
  @moduledoc """
  A single posting (leg) of a `Beancount.Directives.Transaction`.

  A posting moves an amount in a commodity into or out of an account. The
  `amount` and `currency` may be `nil` to represent an elided amount that
  Beancount infers when balancing a transaction.
  """

  alias Beancount.Renderer

  @enforce_keys [:account]
  defstruct account: nil,
            amount: nil,
            currency: nil,
            cost: nil,
            price: nil,
            flag: nil,
            metadata: %{}

  @typedoc "A cost specification, e.g. `{10.00 USD}`."
  @type cost :: %{amount: Decimal.t(), currency: String.t()} | nil

  @typedoc "A price annotation, e.g. `@ 1.2 USD` or `@@ 120 USD`."
  @type price ::
          %{amount: Decimal.t(), currency: String.t(), type: :unit | :total} | nil

  @type t :: %__MODULE__{
          account: String.t(),
          amount: Decimal.t() | nil,
          currency: String.t() | nil,
          cost: cost(),
          price: price(),
          flag: String.t() | nil,
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(posting), do: Renderer.render_postings([posting]) |> Renderer.lines_to_fragment()
  end
end
