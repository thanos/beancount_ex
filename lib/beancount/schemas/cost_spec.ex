defmodule Beancount.Schemas.CostSpec do
  @moduledoc """
  Persisted cost/lot specification (embedded schema).

  Storage-layer counterpart of `Beancount.CostSpec`. Embedded inside
  `Beancount.Schemas.Posting` via `embeds_one/3`; it has no table of its own.

  ## Fields

    * `per_amount` - per-unit cost as `Decimal.t()`, or `nil`.
    * `per_currency` - currency for `per_amount`.
    * `total_amount` - total cost for all units (`{{...}}`), or `nil`.
    * `total_currency` - currency for `total_amount`.
    * `date` - acquisition `Date.t()` used for lot matching, or `nil`.
    * `label` - lot label string, or `nil`.
    * `merge` - when `true`, matching lots are merged on deposit.

  ## Example

      %Beancount.Schemas.CostSpec{
        per_amount: Decimal.new("150"),
        per_currency: "USD",
        total_amount: nil,
        total_currency: nil,
        date: ~D[2026-01-02],
        label: "lot-a",
        merge: false
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  embedded_schema do
    field(:per_amount, :decimal)
    field(:per_currency, :string)
    field(:total_amount, :decimal)
    field(:total_currency, :string)
    field(:date, :date)
    field(:label, :string)
    field(:merge, :boolean)
  end
end
