defmodule Beancount.Schemas.Posting do
  @moduledoc """
  Persisted transaction posting (embedded schema).

  Storage-layer counterpart of `Beancount.Directives.Posting`. Embedded inside
  `Beancount.Schemas.Transaction` via `embeds_many/3`; it has no table of its
  own and no `file_order` (ordering follows the enclosing transaction).

  ## Fields

    * `account` - account the posting affects, e.g. `"Assets:Bank"`.
    * `amount` - posting quantity as `Decimal.t()`, or `nil` for an elided leg.
    * `currency` - commodity of `amount`, or `nil` when elided.
    * `cost` - embedded `Beancount.Schemas.CostSpec` for lot cost, or `nil`.
    * `price` - price annotation map (`@`/`@@`), or `nil`.
    * `flag` - optional per-posting flag, e.g. `"!"`.
    * `metadata` - arbitrary key/value map.

  ## Example

      %Beancount.Schemas.Posting{
        account: "Assets:Stocks",
        amount: Decimal.new("10"),
        currency: "AAPL",
        cost: %Beancount.Schemas.CostSpec{per_amount: Decimal.new("150"), per_currency: "USD"},
        price: nil,
        flag: nil,
        metadata: %{}
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:account, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    embeds_one(:cost, Beancount.Schemas.CostSpec)
    embeds_one(:price, Beancount.Schemas.PriceAnnotation)
    field(:flag, :string)
    field(:metadata, :map)
  end
end

defmodule Beancount.Schemas.PriceAnnotation do
  @moduledoc """
  Persisted posting price annotation (embedded schema).

  Storage-layer counterpart of a `Beancount.Directives.Posting` `:price` map
  (`@`/`@@`). Embedded inside `Beancount.Schemas.Posting` via `embeds_one/3`;
  it has no table of its own.

  Storing the price as a typed embedded schema (rather than a bare map) keeps
  `amount` a `Decimal.t()` across a database round-trip, so rendering the loaded
  directive produces byte-identical Beancount text.

  ## Fields

    * `amount` - price quantity as `Decimal.t()`.
    * `currency` - commodity of `amount`.
    * `type` - `"unit"` for `@` (per-unit) or `"total"` for `@@` (total) price.

  ## Example

      %Beancount.Schemas.PriceAnnotation{
        amount: Decimal.new("197.90"),
        currency: "USD",
        type: "unit"
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:amount, :decimal)
    field(:currency, :string)
    field(:type, :string)
  end
end
