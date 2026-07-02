defmodule Beancount.Schemas.CostSpec do
  use Ecto.Schema

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
