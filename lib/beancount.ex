defmodule Beancount do
  @moduledoc """
  Idiomatic Elixir interface to [Beancount](https://beancount.github.io/).

  `beancount_ex` is **not** a General Ledger. It is a compatibility layer and
  *behavioral oracle*: it constructs Beancount directives as typed Elixir
  structs, renders them to deterministic `.bean` text, and validates them
  through a configurable engine. The default engine wraps real Beancount
  (`bean-check` / `bean-query`); the native `Beancount.Engine.Elixir` can
  replace it **without changing this public API**.

  Optional persistence: `Beancount.Storage` stores directives in SQLite via
  Ecto; `Beancount.Queries` reads them back without running the booking engine.

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

  alias Beancount.{CostSpec, Engine, Value}

  alias Beancount.Directives.{
    Balance,
    Close,
    Commodity,
    Custom,
    Document,
    Event,
    Include,
    Note,
    Open,
    Option,
    Pad,
    Plugin,
    PopTag,
    Posting,
    Price,
    PushTag,
    Query,
    Transaction
  }

  @typedoc "A renderable Beancount directive struct."
  @type directive :: Beancount.Directive.t()

  # Directive constructors

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

    * `:cost` - a `Beancount.CostSpec` struct or legacy `%{amount:, currency:}` map.
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
      cost: opts |> Keyword.get(:cost) |> CostSpec.normalize(),
      price: Keyword.get(opts, :price),
      flag: Keyword.get(opts, :flag),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a `balance` assertion directive.

  Options:

    * `:tolerance` - explicit tolerance, rendered as `AMOUNT ~ TOLERANCE CURRENCY`.
    * `:metadata` - a map of metadata key/values.

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
      tolerance: Keyword.get(opts, :tolerance),
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

  @doc """
  Build a `pad` directive.

  ## Examples

      iex> Beancount.pad(~D[2025-12-20], "Assets:Cash", "Equity:Opening").account
      "Assets:Cash"

  """
  @spec pad(Date.t(), String.t(), String.t(), keyword()) :: Pad.t()
  def pad(date, account, source_account, opts \\ []) do
    %Pad{
      date: date,
      account: account,
      source_account: source_account,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build an `include` directive.

  ## Examples

      iex> Beancount.include("accounts.bean").path
      "accounts.bean"

  """
  @spec include(String.t()) :: Include.t()
  def include(path) when is_binary(path), do: %Include{path: path}

  @doc """
  Build an `option` directive.

  Common keys: `title`, `operating_currency`, `inferred_tolerance_default`,
  `inferred_tolerance_multiplier`, `infer_tolerance_from_cost`, `tolerance_multiplier`.

  ## Examples

      iex> Beancount.option("title", "My Ledger").name
      "title"

  """
  @spec option(String.t(), term()) :: Option.t()
  def option(name, value) when is_binary(name), do: %Option{name: name, value: value}

  @doc """
  Wrap an account name for use in `custom/4` values.

  ## Examples

      iex> Beancount.account_value("Assets:Bank").name
      "Assets:Bank"

  """
  @spec account_value(String.t()) :: Value.Account.t()
  def account_value(name) when is_binary(name), do: %Value.Account{name: name}

  @doc """
  Wrap a tag name for use in `custom/4` values (rendered as `#tag`).

  ## Examples

      iex> Beancount.tag_value("trip").name
      "trip"

  """
  @spec tag_value(String.t()) :: Value.Tag.t()
  def tag_value(name) when is_binary(name), do: %Value.Tag{name: name}

  @doc """
  Wrap a commodity amount for use in `custom/4` values.

  ## Examples

      iex> v = Beancount.amount_value(Decimal.new("42"), "USD")
      iex> v.currency
      "USD"

  """
  @spec amount_value(Decimal.t(), String.t()) :: Value.Amount.t()
  def amount_value(%Decimal{} = number, currency) when is_binary(currency) do
    %Value.Amount{number: number, currency: currency}
  end

  @doc """
  Build a `query` directive storing a named BQL query in the ledger.

  ## Examples

      iex> q = Beancount.query_directive(~D[2026-01-01], "balances", "SELECT account")
      iex> q.name
      "balances"

  """
  @spec query_directive(Date.t(), String.t(), String.t(), keyword()) :: Query.t()
  def query_directive(date, name, bql, opts \\ []) when is_binary(name) and is_binary(bql) do
    %Query{date: date, name: name, bql: bql, metadata: Keyword.get(opts, :metadata, %{})}
  end

  @doc """
  Build a `plugin` directive.

  ## Examples

      iex> Beancount.plugin("beancount.plugins.auto_accounts").module
      "beancount.plugins.auto_accounts"

  """
  @spec plugin(String.t(), String.t() | nil) :: Plugin.t()
  def plugin(module, config \\ nil) when is_binary(module) do
    %Plugin{module: module, config: config}
  end

  @doc """
  Build a `pushtag` directive.

  ## Examples

      iex> Beancount.push_tag("vacation").tag
      "vacation"

  """
  @spec push_tag(String.t()) :: PushTag.t()
  def push_tag(tag) when is_binary(tag), do: %PushTag{tag: tag}

  @doc """
  Build a `poptag` directive.

  ## Examples

      iex> Beancount.pop_tag("vacation").tag
      "vacation"

  """
  @spec pop_tag(String.t()) :: PopTag.t()
  def pop_tag(tag) when is_binary(tag), do: %PopTag{tag: tag}

  # Parsing

  @doc """
  Parse a directive list or `.bean` text. See `Beancount.Parser.parse/1`.

  ## Examples

      iex> {:ok, directives} = Beancount.parse([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
      iex> hd(directives).account
      "Assets:Bank"

      iex> {:ok, directives} = Beancount.parse_text("2026-01-01 open Assets:Bank USD\\n")
      iex> hd(directives).account
      "Assets:Bank"

  """
  @spec parse([directive()] | binary()) ::
          {:ok, [directive()]} | {:error, Beancount.Parser.Error.t()}
  defdelegate parse(input), to: Beancount.Parser

  @doc """
  Parse `.bean` text into directives. See `Beancount.Parser.parse_text/1`.

  ## Examples

      iex> {:ok, directives} = Beancount.parse_text("2026-01-01 commodity USD\\n")
      iex> hd(directives).currency
      "USD"

  """
  @spec parse_text(binary()) :: {:ok, [directive()]} | {:error, Beancount.Parser.Error.t()}
  defdelegate parse_text(text), to: Beancount.Parser

  @doc """
  Parse a `.bean` file from disk. See `Beancount.Parser.parse_file/1`.

  ## Examples

      path = Path.join(System.tmp_dir!(), "parse_example.bean")
      File.write!(path, "2026-01-01 open Assets:Bank USD\\n")

      {:ok, [%Beancount.Directives.Open{} = open]} = Beancount.parse_file(path)
      open.account
      # => "Assets:Bank"

  """
  @spec parse_file(Path.t()) ::
          {:ok, [directive()]} | {:error, Beancount.Parser.Error.t() | term()}
  defdelegate parse_file(path), to: Beancount.Parser

  @doc """
  Parse `.bean` text, raising on failure. See `Beancount.Parser.parse!/1`.

  ## Examples

      iex> Beancount.parse!("2026-01-01 open Assets:Bank USD\\n")
      ...> |> hd()
      ...> |> Map.get(:account)
      "Assets:Bank"

  """
  @spec parse!(binary()) :: [directive()]
  defdelegate parse!(text), to: Beancount.Parser

  # Engine dispatch

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

  ## Examples

  With the configured engine:

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, %Beancount.Result{status: :ok}} = Beancount.check(ledger)

  """
  @spec check([directive()]) :: {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  def check(directives) when is_list(directives) do
    directives |> render() |> check_text()
  end

  @doc """
  Validate raw `.bean` text through the configured engine.

  ## Examples

      text = \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\"

      {:ok, %Beancount.Result{status: :ok}} = Beancount.Engine.Elixir.check(text)

  """
  @spec check_text(binary()) :: {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  def check_text(text) when is_binary(text) do
    Engine.configured().check(text)
  end

  @doc """
  Validate a `.bean` file on disk through the configured engine.

  ## Examples

      path = Path.join(System.tmp_dir!(), "check_example.bean")

      File.write!(path, \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\")

      {:ok, %Beancount.Result{status: :ok}} = Beancount.Engine.Elixir.check_file(path)

  """
  @spec check_file(Path.t()) :: {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  def check_file(path) do
    Engine.configured().check_file(path)
  end

  @typedoc "A successful BQL query result or a failure result."
  @type query_return :: {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Run a BQL query against a directive stream.

  The directives are rendered to `.bean` text and the query is dispatched
  through the configured engine's `c:Beancount.Engine.query/2`.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      bql = "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"

      {:ok, %Beancount.Query.Result{columns: columns}} =
        ledger |> Beancount.render() |> then(&Beancount.Engine.Elixir.query(&1, bql))

      columns
      # => ["account", "balance"]

  """
  @spec query([directive()], binary()) :: query_return()
  def query(directives, bql) when is_list(directives) and is_binary(bql) do
    directives |> render() |> query_text(bql)
  end

  @doc """
  Run a BQL query against raw `.bean` text through the configured engine.

  ## Examples

      text = \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD
      2026-01-01 open Equity:Opening USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\"

      {:ok, result} =
        Beancount.Engine.Elixir.query(
          text,
          "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
        )

      result.columns
      # => ["account", "balance"]

  """
  @spec query_text(binary(), binary()) :: query_return()
  def query_text(text, bql) when is_binary(text) and is_binary(bql) do
    Engine.configured().query(text, bql)
  end

  @doc """
  Run a BQL query against a `.bean` file on disk through the configured engine.

  ## Examples

      path = Path.join(System.tmp_dir!(), "query_example.bean")

      File.write!(path, \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD
      2026-01-01 open Equity:Opening USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\")

      {:ok, _} =
        Beancount.Engine.Elixir.query(
          File.read!(path),
          "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
        )

  """
  @spec query_file(Path.t(), binary()) :: query_return()
  def query_file(path, bql) when is_binary(bql) do
    path |> File.read!() |> query_text(bql)
  end

  # Reporting (delegates to Beancount.Report)

  @doc """
  Account balances report. See `Beancount.Report.balances/1`.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, %Beancount.Query.Result{}} =
        ledger |> Beancount.render() |> then(&Beancount.Engine.Elixir.query(&1, "SELECT account, sum(position) GROUP BY account"))

  """
  @spec balances([directive()] | binary()) :: query_return()
  defdelegate balances(ledger), to: Beancount.Report

  @doc """
  Balance sheet report. See `Beancount.Report.balance_sheet/1`.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Open", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Equity:Opening", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, %Beancount.Query.Result{}} =
        ledger |> Beancount.render() |> then(&Beancount.Report.balance_sheet/1)

  """
  @spec balance_sheet([directive()] | binary()) :: query_return()
  defdelegate balance_sheet(ledger), to: Beancount.Report

  @doc """
  Income statement report. See `Beancount.Report.income_statement/1`.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, %Beancount.Query.Result{}} = Beancount.Report.income_statement(ledger)

  """
  @spec income_statement([directive()] | binary()) :: query_return()
  defdelegate income_statement(ledger), to: Beancount.Report

  @doc """
  Holdings report. See `Beancount.Report.holdings/1`.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
        Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
        Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
          Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
            cost: %{amount: Decimal.new("150"), currency: "USD"}
          ),
          Beancount.posting("Assets:Cash", Decimal.new("-1500"), "USD")
        ])
      ]

      {:ok, %Beancount.Query.Result{columns: cols}} = Beancount.Report.holdings(ledger)
      cols
      # => ["account", "units", "cost"]

  """
  @spec holdings([directive()] | binary()) :: query_return()
  defdelegate holdings(ledger), to: Beancount.Report

  @doc """
  Per-account journal report. See `Beancount.Report.journal/2`.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, %Beancount.Query.Result{}} = Beancount.Report.journal(ledger, "Assets:Bank")

  """
  @spec journal([directive()] | binary(), String.t()) :: query_return()
  defdelegate journal(ledger, account), to: Beancount.Report
end
