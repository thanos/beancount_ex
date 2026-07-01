defmodule Beancount.Directives.Posting do
  @moduledoc """
  A single posting (leg) of a `Beancount.Directives.Transaction`.

  See [Costs and Prices](https://beancount.github.io/docs/beancount_language_syntax/#costs-and-prices)
  in the Beancount syntax guide.

  ## Beancount syntax

      Assets:ETrade:IVV   -10 IVV {183.07 USD} @ 197.90 USD
        trade-id: "T-991"

      Expenses:Restaurant

  A posting may elide amount and currency; Beancount infers them when balancing.

  ## Elixir struct

      %Beancount.Directives.Posting{
        account: "Assets:ETrade:IVV",
        amount: Decimal.new("-10"),
        currency: "IVV",
        cost: %Beancount.CostSpec{
          per_amount: Decimal.new("183.07"),
          per_currency: "USD",
          total_amount: nil,
          total_currency: nil,
          date: nil,
          label: nil,
          merge: false
        },
        price: %{amount: Decimal.new("197.90"), currency: "USD", type: :unit},
        flag: nil,
        metadata: %{"trade-id" => "T-991"}
      }

  Elided amount (inferred by Beancount):

      %Beancount.Directives.Posting{
        account: "Expenses:Restaurant",
        amount: nil,
        currency: nil,
        cost: nil,
        price: nil,
        flag: nil,
        metadata: %{}
      }

  Or use `Beancount.posting/4`:

      Beancount.posting("Assets:ETrade:IVV", Decimal.new("-10"), "IVV",
        cost: %{amount: Decimal.new("183.07"), currency: "USD"},
        price: %{amount: Decimal.new("197.90"), currency: "USD", type: :unit},
        metadata: %{"trade-id" => "T-991"}
      )

  ## Fields

    * `account` - colon-separated account receiving the posting.
    * `amount` - `Decimal.t()` units posted, or `nil` to elide (Beancount
      interpolates the balancing amount).
    * `currency` - commodity symbol for `amount`, or `nil` when elided.
    * `cost` - `Beancount.CostSpec` (or legacy `%{amount:, currency:}` map)
      for inventory held at cost, e.g. `{183.07 USD}`. `nil` for simple amounts.
    * `price` - unit price `%{amount:, currency:, type: :unit}` (`@ 1.2 USD`)
      or total price `type: :total` (`@@ 120 USD`). `nil` when absent.
    * `flag` - optional per-posting flag (`"!"`, etc.) rendered before the
      account name.
    * `metadata` - optional map rendered as indented lines under the posting.
  """

  alias Beancount.CostSpec
  alias Beancount.Renderer

  @enforce_keys [:account]
  defstruct account: nil,
            amount: nil,
            currency: nil,
            cost: nil,
            price: nil,
            flag: nil,
            metadata: %{}

  @typedoc "A cost specification. See `Beancount.CostSpec`."
  @type cost :: CostSpec.t() | map() | nil

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
