defmodule Beancount.Schemas.Posting do
  use Ecto.Schema

  embedded_schema do
    field(:account, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    embeds_one(:cost, Beancount.Schemas.CostSpec)
    field(:price, :map)
    field(:flag, :string)
    field(:metadata, :map)
  end
end
