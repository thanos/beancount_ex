defmodule Beancount.Schemas.Transaction do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_transactions" do
    field(:date, :date)
    field(:flag, :string)
    field(:payee, :string)
    field(:narration, :string)
    field(:tags, {:array, :string})
    field(:links, {:array, :string})
    field(:metadata, :map)
    field(:file_order, :integer)
    embeds_many(:postings, Beancount.Schemas.Posting)

    timestamps()
  end
end
