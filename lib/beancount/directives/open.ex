defmodule Beancount.Directives.Open do
  @moduledoc """
  The `open` directive declares the start of an account's life.

  See the [Beancount Open directive](https://beancount.github.io/docs/beancount_language_syntax/#open).

  ## Beancount syntax

      2026-01-01 open Assets:Bank USD,EUR "STRICT"
        note: "Primary checking"

  General form: `YYYY-MM-DD open Account [Currency,...] ["BookingMethod"]`

  ## Elixir struct

      %Beancount.Directives.Open{
        date: ~D[2026-01-01],
        account: "Assets:Bank",
        currencies: ["USD", "EUR"],
        booking: "STRICT",
        metadata: %{"note" => "Primary checking"}
      }

  Prefer `Beancount.open/4` when building ledgers programmatically:

      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD", "EUR"],
        booking: "STRICT",
        metadata: %{"note" => "Primary checking"}
      )

  ## Fields

    * `date` - `Date.t()` when the account becomes active. Must be on or before the
      first posting to this account.
    * `account` - colon-separated account name, e.g. `"Assets:Bank"`.
    * `currencies` - optional list of allowed commodities for postings to this
      account. Empty list `[]` means no constraint. Rendered comma-separated in
      the `.bean` file.
    * `booking` - lot-matching method when a reducing posting is ambiguous.
      Common values: `"STRICT"` (default; error on ambiguity), `"NONE"`,
      `"FIFO"`, `"LIFO"`, `"AVERAGE"`, `"HIFO"`. `nil` omits the booking clause.
    * `metadata` - optional map of key/value pairs rendered as indented metadata
      lines below the directive.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account]
  defstruct date: nil, account: nil, currencies: [], booking: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          currencies: [String.t()],
          booking: String.t() | nil,
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account} = open) do
      header =
        [Renderer.format_date(date), "open", account]
        |> Enum.join(" ")
        |> append_currencies(open.currencies)
        |> append_booking(open.booking)

      Renderer.lines_to_fragment([header | Renderer.render_metadata(open.metadata)])
    end

    defp append_currencies(header, []), do: header
    defp append_currencies(header, currencies), do: header <> " " <> Enum.join(currencies, ",")

    defp append_booking(header, nil), do: header
    defp append_booking(header, booking), do: header <> " " <> Renderer.quote_string(booking)
  end
end
