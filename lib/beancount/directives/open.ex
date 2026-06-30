defmodule Beancount.Directives.Open do
  @moduledoc """
  The `open` directive declares the start of an account's life.

      2026-01-01 open Assets:Bank USD,EUR

  An optional list of allowed `currencies` and a `booking` method may be
  provided.
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
