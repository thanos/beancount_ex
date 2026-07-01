defmodule Beancount.Directives.Transaction do
  @moduledoc """
  The `transaction` directive records a balanced movement between accounts.

  See the [Beancount Transactions section](https://beancount.github.io/docs/beancount_language_syntax/#transactions).

  ## Beancount syntax

      2026-01-31 * "Employer" "Salary" #paycheck ^jan-2026
        order-id: "INV-42"
        Assets:Bank      5000 USD
        Income:Salary   -5000 USD

  General form: `YYYY-MM-DD FLAG ["Payee"] "Narration" [#tag] [^link]`

  ## Elixir struct

      %Beancount.Directives.Transaction{
        date: ~D[2026-01-31],
        flag: "*",
        payee: "Employer",
        narration: "Salary",
        postings: [
          %Beancount.Directives.Posting{
            account: "Assets:Bank",
            amount: Decimal.new("5000"),
            currency: "USD",
            cost: nil,
            price: nil,
            flag: nil,
            metadata: %{}
          },
          %Beancount.Directives.Posting{
            account: "Income:Salary",
            amount: Decimal.new("-5000"),
            currency: "USD",
            cost: nil,
            price: nil,
            flag: nil,
            metadata: %{}
          }
        ],
        tags: ["paycheck"],
        links: ["jan-2026"],
        metadata: %{"order-id" => "INV-42"}
      }

  Or use `Beancount.transaction/6`:

      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
      ],
      tags: ["paycheck"],
      links: ["jan-2026"],
      metadata: %{"order-id" => "INV-42"}
      )

  ## Fields

    * `date` - `Date.t()` of the transaction.
    * `flag` - status flag, typically `"*"` (complete) or `"!"` (needs review).
    * `payee` - optional counterparty string. `nil` renders narration only.
    * `narration` - required description string (may be empty `""`).
    * `postings` - list of `Beancount.Directives.Posting` legs. Must balance to
      zero in all currencies when validated.
    * `tags` - list of tag names (without `#`), applied to the transaction header.
    * `links` - list of link names (without `^`), for grouping related entries.
    * `metadata` - optional map rendered on the transaction before postings.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :flag, :postings]
  defstruct date: nil,
            flag: "*",
            payee: nil,
            narration: "",
            postings: [],
            tags: [],
            links: [],
            metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          flag: String.t(),
          payee: String.t() | nil,
          narration: String.t(),
          postings: [Beancount.Directives.Posting.t()],
          tags: [String.t()],
          links: [String.t()],
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(txn) do
      header =
        Renderer.format_date(txn.date) <>
          " " <>
          txn.flag <>
          description(txn.payee, txn.narration) <>
          Renderer.render_tags_and_links(txn.tags, txn.links)

      lines =
        [header] ++
          Renderer.render_metadata(txn.metadata) ++
          Renderer.render_postings(txn.postings)

      Renderer.lines_to_fragment(lines)
    end

    defp description(nil, narration), do: " " <> Renderer.quote_string(narration)

    defp description(payee, narration) do
      " " <> Renderer.quote_string(payee) <> " " <> Renderer.quote_string(narration)
    end
  end
end
