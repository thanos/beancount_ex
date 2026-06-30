defmodule Beancount do
  @moduledoc """
  Idiomatic Elixir interface to [Beancount](https://beancount.github.io/).

  `beancount_ex` is **not** a General Ledger. It is a compatibility layer and
  *behavioral oracle*: it constructs Beancount directives as typed Elixir
  structs, renders them to deterministic `.bean` text, and validates them
  through a configurable engine. Today that engine wraps real Beancount; a
  future native Elixir (or Rust) engine can replace it **without changing this
  public API**.

  ## Quick start

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
        ])
      ]

      bean = Beancount.render(ledger)
      {:ok, result} = Beancount.check(ledger)

  The constructor functions (`open/4`, `transaction/6`, `posting/4`, ...) build
  the typed structs under `Beancount.Directives`. You never need to reference
  that namespace directly.
  """

  alias Beancount.Engine

  alias Beancount.Directives.{
    Balance,
    Close,
    Commodity,
    Custom,
    Document,
    Event,
    Note,
    Open,
    Posting,
    Price,
    Transaction
  }

  @typedoc "A renderable Beancount directive struct."
  @type directive :: Beancount.Directive.t()

  # ── Directive constructors ────────────────────────────────────────────────

  @doc """
  Build an `open` directive.

  ## Options

    * `:booking` - booking method, e.g. `"STRICT"`.
    * `:metadata` - a map of metadata key/values.

  ## Examples

      iex> Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])
      %Beancount.Directives.Open{
        date: ~D[2026-01-01],
        account: "Assets:Bank",
        currencies: ["USD"],
        booking: nil,
        metadata: %{}
      }

  """
  @spec open(Date.t(), String.t(), [String.t()], keyword()) :: Open.t()
  def open(date, account, currencies \\ [], opts \\ []) do
    %Open{
      date: date,
      account: account,
      currencies: currencies,
      booking: Keyword.get(opts, :booking),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `close` directive.

  ## Examples

      iex> Beancount.close(~D[2026-12-31], "Assets:Bank").account
      "Assets:Bank"

  """
  @spec close(Date.t(), String.t(), keyword()) :: Close.t()
  def close(date, account, opts \\ []) do
    %Close{date: date, account: account, metadata: Keyword.get(opts, :metadata, %{})}
  end

  @doc """
  Build a `commodity` directive.

  ## Examples

      iex> Beancount.commodity(~D[2026-01-01], "USD").currency
      "USD"

  """
  @spec commodity(Date.t(), String.t(), keyword()) :: Commodity.t()
  def commodity(date, currency, opts \\ []) do
    %Commodity{date: date, currency: currency, metadata: Keyword.get(opts, :metadata, %{})}
  end

  @doc """
  Build a `transaction` directive.

  `payee` may be `nil` to render only a narration. Options:

    * `:tags` - list of tag strings (rendered as `#tag`).
    * `:links` - list of link strings (rendered as `^link`).
    * `:metadata` - a map of metadata key/values.

  ## Examples

      iex> txn = Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [])
      iex> txn.flag
      "*"

  """
  @spec transaction(Date.t(), String.t(), String.t() | nil, String.t(), [Posting.t()], keyword()) ::
          Transaction.t()
  def transaction(date, flag, payee, narration, postings, opts \\ []) do
    %Transaction{
      date: date,
      flag: flag,
      payee: payee,
      narration: narration,
      postings: postings,
      tags: Keyword.get(opts, :tags, []),
      links: Keyword.get(opts, :links, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `posting` (a leg of a transaction).

  `amount` and `currency` may be `nil` for an elided amount. Options:

    * `:cost` - a `%{amount: Decimal.t(), currency: String.t()}` cost basis.
    * `:price` - a `%{amount: Decimal.t(), currency: String.t(), type: :unit | :total}` price.
    * `:flag` - a per-posting flag.
    * `:metadata` - a map of metadata key/values.

  ## Examples

      iex> Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD").account
      "Assets:Bank"

  """
  @spec posting(String.t(), Decimal.t() | nil, String.t() | nil, keyword()) :: Posting.t()
  def posting(account, amount \\ nil, currency \\ nil, opts \\ []) do
    %Posting{
      account: account,
      amount: amount,
      currency: currency,
      cost: Keyword.get(opts, :cost),
      price: Keyword.get(opts, :price),
      flag: Keyword.get(opts, :flag),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `balance` assertion directive.

  ## Examples

      iex> Beancount.balance(~D[2026-01-31], "Assets:Bank", Decimal.new("5000"), "USD").currency
      "USD"

  """
  @spec balance(Date.t(), String.t(), Decimal.t(), String.t(), keyword()) :: Balance.t()
  def balance(date, account, amount, currency, opts \\ []) do
    %Balance{
      date: date,
      account: account,
      amount: amount,
      currency: currency,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `price` directive.

  ## Examples

      iex> Beancount.price(~D[2026-01-01], "USD", Decimal.new("1.20"), "CAD").commodity
      "USD"

  """
  @spec price(Date.t(), String.t(), Decimal.t(), String.t(), keyword()) :: Price.t()
  def price(date, commodity, amount, currency, opts \\ []) do
    %Price{
      date: date,
      commodity: commodity,
      amount: amount,
      currency: currency,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `note` directive.

  ## Examples

      iex> Beancount.note(~D[2026-01-01], "Assets:Bank", "Called about fees").comment
      "Called about fees"

  """
  @spec note(Date.t(), String.t(), String.t(), keyword()) :: Note.t()
  def note(date, account, comment, opts \\ []) do
    %Note{
      date: date,
      account: account,
      comment: comment,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `document` directive.

  ## Examples

      iex> Beancount.document(~D[2026-01-01], "Assets:Bank", "stmt.pdf").path
      "stmt.pdf"

  """
  @spec document(Date.t(), String.t(), String.t(), keyword()) :: Document.t()
  def document(date, account, path, opts \\ []) do
    %Document{
      date: date,
      account: account,
      path: path,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build an `event` directive.

  ## Examples

      iex> Beancount.event(~D[2026-01-01], "location", "New York").type
      "location"

  """
  @spec event(Date.t(), String.t(), String.t(), keyword()) :: Event.t()
  def event(date, type, description, opts \\ []) do
    %Event{
      date: date,
      type: type,
      description: description,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `custom` directive.

  ## Examples

      iex> Beancount.custom(~D[2026-01-01], "budget", ["monthly"]).type
      "budget"

  """
  @spec custom(Date.t(), String.t(), [term()], keyword()) :: Custom.t()
  def custom(date, type, values \\ [], opts \\ []) do
    %Custom{
      date: date,
      type: type,
      values: values,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  # ── Engine dispatch ───────────────────────────────────────────────────────

  @doc """
  Render a directive stream to deterministic `.bean` text.

  Dispatches to the configured engine's `c:Beancount.Engine.render/1`.

  ## Examples

      iex> Beancount.render([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
      "2026-01-01 open Assets:Bank USD\\n"

  """
  @spec render([directive()]) :: binary()
  def render(directives) when is_list(directives) do
    Engine.configured().render(directives)
  end

  @doc """
  Render `directives` and validate the result through the configured engine.

  Returns `{:ok, result}` for a valid ledger and `{:error, result}` otherwise.
  """
  @spec check([directive()]) :: {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  def check(directives) when is_list(directives) do
    directives |> render() |> check_text()
  end

  @doc """
  Validate raw `.bean` text through the configured engine.
  """
  @spec check_text(binary()) :: {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  def check_text(text) when is_binary(text) do
    Engine.configured().check(text)
  end

  @doc """
  Validate a `.bean` file on disk through the configured engine.
  """
  @spec check_file(Path.t()) :: {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  def check_file(path) do
    path |> File.read!() |> check_text()
  end

  @typedoc "A successful BQL query result or a failure result."
  @type query_return :: {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Run a BQL query against a directive stream.

  The directives are rendered to `.bean` text and the query is dispatched
  through the configured engine's `c:Beancount.Engine.query/2`.
  """
  @spec query([directive()], binary()) :: query_return()
  def query(directives, bql) when is_list(directives) and is_binary(bql) do
    directives |> render() |> query_text(bql)
  end

  @doc """
  Run a BQL query against raw `.bean` text through the configured engine.
  """
  @spec query_text(binary(), binary()) :: query_return()
  def query_text(text, bql) when is_binary(text) and is_binary(bql) do
    Engine.configured().query(text, bql)
  end

  @doc """
  Run a BQL query against a `.bean` file on disk through the configured engine.
  """
  @spec query_file(Path.t(), binary()) :: query_return()
  def query_file(path, bql) when is_binary(bql) do
    path |> File.read!() |> query_text(bql)
  end

  # ── Reporting (delegates to Beancount.Report) ─────────────────────────────

  @doc "Account balances report. See `Beancount.Report.balances/1`."
  @spec balances([directive()] | binary()) :: query_return()
  defdelegate balances(ledger), to: Beancount.Report

  @doc "Balance sheet report. See `Beancount.Report.balance_sheet/1`."
  @spec balance_sheet([directive()] | binary()) :: query_return()
  defdelegate balance_sheet(ledger), to: Beancount.Report

  @doc "Income statement report. See `Beancount.Report.income_statement/1`."
  @spec income_statement([directive()] | binary()) :: query_return()
  defdelegate income_statement(ledger), to: Beancount.Report

  @doc "Holdings report. See `Beancount.Report.holdings/1`."
  @spec holdings([directive()] | binary()) :: query_return()
  defdelegate holdings(ledger), to: Beancount.Report

  @doc "Per-account journal report. See `Beancount.Report.journal/2`."
  @spec journal([directive()] | binary(), String.t()) :: query_return()
  defdelegate journal(ledger, account), to: Beancount.Report
end
