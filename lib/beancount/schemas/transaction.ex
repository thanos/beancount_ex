defmodule Beancount.Schemas.Transaction do
  @moduledoc """
  Persisted `transaction` directive (table `beancount_transactions`).

  Storage-layer counterpart of `Beancount.Directives.Transaction`. Postings are
  stored inline as embedded `Beancount.Schemas.Posting` rows (no separate
  table).

  ## Fields

    * `date` - the day the transaction is booked.
    * `flag` - transaction flag, e.g. `"*"` (completed) or `"!"` (pending).
    * `payee` - optional payee string, or `nil`.
    * `narration` - free-text description of the transaction.
    * `tags` - list of tag names without `#`, e.g. `["trip-athens"]`.
    * `links` - list of link names without `^`, e.g. `["invoice-042"]`.
    * `metadata` - arbitrary key/value map.
    * `postings` - embedded list of `Beancount.Schemas.Posting`.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Transaction{
        date: ~D[2026-01-31],
        flag: "*",
        payee: "Employer",
        narration: "Salary",
        tags: [],
        links: [],
        metadata: %{},
        file_order: 3,
        postings: [
          %Beancount.Schemas.Posting{account: "Assets:Bank", amount: Decimal.new("5000"), currency: "USD"},
          %Beancount.Schemas.Posting{account: "Income:Salary", amount: Decimal.new("-5000"), currency: "USD"}
        ]
      }

  """
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
