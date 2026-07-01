defmodule Beancount.Directives.Balance do
  @moduledoc """
  The `balance` directive asserts an account balance at a date.

  See [Balance Assertions](https://beancount.github.io/docs/beancount_language_syntax/#balance-assertions).

  ## Beancount syntax

      2026-01-31 balance Assets:Bank   5000 USD
      2026-01-31 balance Assets:Bank   1.5 ~ 0.5 USD

  General form: `YYYY-MM-DD balance Account Amount [~ Tolerance] Currency`

  The check runs at the **beginning** of `date` (midnight).

  ## Elixir struct

      %Beancount.Directives.Balance{
        date: ~D[2026-01-31],
        account: "Assets:Bank",
        amount: Decimal.new("1.5"),
        currency: "USD",
        tolerance: Decimal.new("0.5"),
        metadata: %{}
      }

  Or use `Beancount.balance/5`:

      Beancount.balance(~D[2026-01-31], "Assets:Bank", Decimal.new("1.5"), "USD",
        tolerance: Decimal.new("0.5")
      )

  ## Fields

    * `date` - `Date.t()` when the assertion is evaluated (start of day).
    * `account` - account whose balance is checked (may be a parent account).
    * `amount` - expected `Decimal.t()` balance in `currency`.
    * `currency` - commodity symbol being asserted.
    * `tolerance` - optional `Decimal.t()` for explicit local tolerance
      (`amount ~ tolerance currency`). `nil` uses inferred tolerance from
      options.
    * `metadata` - optional map rendered below the directive.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :amount, :currency]
  defstruct date: nil, account: nil, amount: nil, currency: nil, tolerance: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          tolerance: Decimal.t() | nil,
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, amount: amount, currency: currency} = balance) do
      amount_text = Renderer.format_decimal(amount)

      tolerance_text =
        case balance.tolerance do
          %Decimal{} = tolerance -> " ~ " <> Renderer.format_decimal(tolerance)
          _ -> ""
        end

      header =
        Renderer.format_date(date) <>
          " balance " <>
          account <> "  " <> amount_text <> tolerance_text <> " " <> currency

      Renderer.lines_to_fragment([header | Renderer.render_metadata(balance.metadata)])
    end
  end
end
