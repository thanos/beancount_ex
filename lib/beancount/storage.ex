defmodule Beancount.Storage do
  @moduledoc """
  Storage and import/export for Beancount directives via Ecto.

  `Beancount.Storage` is the high-level persistence API. It converts
  `Beancount.Directives.*` structs to `Beancount.Schemas.*` rows (and back),
  backed by `Beancount.Repo`. Use it to load a ledger into the database, read
  it back, or round-trip through `.bean` files.

  For SQL queries over stored rows, use `Beancount.Queries`. For balance
  reports that require inventory booking, use `Beancount.Report` (which runs
  BQL through the configured engine).

  ## Configuration

  The default backend is SQLite in-memory (`:memory:`), which requires no setup
  and is cleared when the OS process exits. Keep `pool_size: 1` with
  `:memory:` — each connection in the pool gets its own empty database.

      config :beancount_ex, Beancount.Repo,
        database: ":memory:",
        pool_size: 1

  For a persistent ledger, point `:database` at a file:

      config :beancount_ex, Beancount.Repo, database: "ledger.db"

  The migration in `priv/repo/migrations` creates one table per directive type;
  the application supervisor runs it on startup.

  ## Public functions

  | Function | Description |
  |----------|-------------|
  | `import_file/1` | Parse a `.bean` file and store the directives |
  | `store/1` | Replace all rows with a directive list |
  | `load/0` | Rebuild directive structs from the database |
  | `export_file/1` | Render stored directives to a `.bean` file |
  | `clear/0` | Delete every row from all directive tables |

  `store/1` and `import_file/1` run in a transaction: existing rows are
  cleared first, then each directive is inserted in source order (`file_order`).

  ## Example: store, query, export

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, 2} = Beancount.Storage.store(ledger)

      [%Beancount.Directives.Open{account: "Assets:Bank"} | _] =
        Beancount.Storage.load()

      Beancount.Queries.list_opens(prefix: "Assets")

      :ok = Beancount.Storage.export_file("out.bean")

  ## Import / export

      {:ok, count} = Beancount.Storage.import_file("ledger.bean")
      :ok = Beancount.Storage.export_file("out.bean")

  Future backends: PostgreSQL (via `postgrex`), Mnesia (via `ecto_mnesia`).
  """
  alias Beancount.Directives, as: D
  alias Beancount.{Parser, Renderer, Repo}
  alias Beancount.Schemas, as: S

  @doc """
  Import directives from a `.bean` file into the database.

  Parses the file and stores the resulting directives, replacing any existing
  rows. Returns the number of directives stored.

  ## Examples

      {:ok, count} = Beancount.Storage.import_file("ledger.bean")
      # => {:ok, 128}

  """
  @spec import_file(Path.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def import_file(path) do
    with {:ok, text} <- File.read(path),
         {:ok, directives} <- Parser.parse_text(text) do
      store(directives)
    end
  end

  @doc """
  Store a list of directives into the database.

  Runs in a transaction that first clears all existing rows, then inserts each
  directive into its matching table. Returns `{:ok, count}` where `count` is the
  number of directives actually stored; entries that are not recognized
  directives are skipped and not counted.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ]

      {:ok, 2} = Beancount.Storage.store(ledger)

  """
  @spec store([Beancount.Directive.t()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def store(directives) do
    Repo.transaction(fn ->
      clear()

      directives
      |> Enum.with_index()
      |> Enum.map(fn {directive, index} -> insert_directive(directive, index) end)
      |> Enum.count(&(&1 != :skip))
    end)
  end

  @doc """
  Load all directives from the database.

  Rebuilds `Beancount.Directives.*` structs from the stored rows. Dated
  directives are returned in date order; undated directives (`option`,
  `include`, `plugin`, `pushtag`, `poptag`) sort ahead of dated ones.

  ## Examples

      Beancount.Storage.store([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])

      [%Beancount.Directives.Open{account: "Assets:Bank"}] = Beancount.Storage.load()

  """
  @spec load() :: [Beancount.Directive.t()]
  def load do
    import Ecto.Query

    tables()
    |> Enum.flat_map(fn {schema, _table} ->
      schema
      |> from(order_by: :file_order)
      |> Repo.all()
      |> Enum.map(fn row -> {row.file_order || 0, to_directive(row)} end)
    end)
    |> Enum.sort_by(fn {file_order, directive} ->
      case directive do
        %{date: %Date{} = d} -> {1, Date.to_iso8601(d), file_order}
        _ -> {0, "", file_order}
      end
    end)
    |> Enum.map(fn {_file_order, directive} -> directive end)
  end

  @doc """
  Export all directives from the database to a `.bean` file.

  Loads every stored directive (see `load/0`) and renders it to Beancount text
  at `path`.

  ## Examples

      :ok = Beancount.Storage.export_file("out.bean")

  """
  @spec export_file(Path.t()) :: :ok | {:error, term()}
  def export_file(path) do
    directives = load()
    File.write(path, Renderer.render(directives))
  end

  @doc """
  Clear all directives from the database.

  Deletes every row from all directive tables. Always returns `:ok`.

  ## Examples

      :ok = Beancount.Storage.clear()
      [] = Beancount.Storage.load()

  """
  @spec clear() :: :ok
  def clear do
    Enum.each(tables(), fn {_schema, table} ->
      Repo.delete_all(table)
    end)

    :ok
  end

  defp tables do
    [
      {S.Open, "beancount_opens"},
      {S.Close, "beancount_closes"},
      {S.Commodity, "beancount_commodities"},
      {S.Transaction, "beancount_transactions"},
      {S.Balance, "beancount_balances"},
      {S.Price, "beancount_prices"},
      {S.Note, "beancount_notes"},
      {S.Document, "beancount_documents"},
      {S.Event, "beancount_events"},
      {S.Custom, "beancount_customs"},
      {S.Pad, "beancount_pads"},
      {S.Include, "beancount_includes"},
      {S.Option, "beancount_options"},
      {S.Plugin, "beancount_plugins"},
      {S.PushTag, "beancount_push_tags"},
      {S.PopTag, "beancount_pop_tags"},
      {S.Query, "beancount_queries"}
    ]
  end

  defp insert_directive(%D.Open{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Close{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Commodity{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Transaction{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Balance{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Price{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Note{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Document{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Event{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Custom{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Pad{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Include{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Option{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Plugin{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.PushTag{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.PopTag{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(%D.Query{} = d, i),
    do: Repo.insert!(to_schema(d, i))

  defp insert_directive(_, _i), do: :skip

  # -- Schema -> Directive struct --

  defp to_directive(%S.Open{} = s) do
    %D.Open{
      date: s.date,
      account: s.account,
      currencies: s.currencies || [],
      booking: s.booking,
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Close{} = s) do
    %D.Close{date: s.date, account: s.account, metadata: decode_meta(s.metadata)}
  end

  defp to_directive(%S.Commodity{} = s) do
    %D.Commodity{date: s.date, currency: s.currency, metadata: decode_meta(s.metadata)}
  end

  defp to_directive(%S.Transaction{} = s) do
    %D.Transaction{
      date: s.date,
      flag: s.flag,
      payee: s.payee,
      narration: s.narration,
      postings: Enum.map(s.postings || [], &posting_to_directive/1),
      tags: s.tags || [],
      links: s.links || [],
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Balance{} = s) do
    %D.Balance{
      date: s.date,
      account: s.account,
      amount: s.amount,
      currency: s.currency,
      tolerance: s.tolerance,
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Price{} = s) do
    %D.Price{
      date: s.date,
      commodity: s.commodity,
      amount: s.amount,
      currency: s.currency,
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Note{} = s) do
    %D.Note{
      date: s.date,
      account: s.account,
      comment: s.comment,
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Document{} = s) do
    %D.Document{date: s.date, account: s.account, path: s.path, metadata: decode_meta(s.metadata)}
  end

  defp to_directive(%S.Event{} = s) do
    %D.Event{
      date: s.date,
      type: s.type,
      description: s.description,
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Custom{} = s) do
    %D.Custom{
      date: s.date,
      type: s.type,
      values: decode_values(s.values),
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Pad{} = s) do
    %D.Pad{
      date: s.date,
      account: s.account,
      source_account: s.source_account,
      metadata: decode_meta(s.metadata)
    }
  end

  defp to_directive(%S.Include{} = s) do
    %D.Include{path: s.path}
  end

  defp to_directive(%S.Option{} = s) do
    %D.Option{name: s.name, value: decode_scalar(s.value)}
  end

  defp to_directive(%S.Plugin{} = s) do
    %D.Plugin{module: s.module, config: s.config}
  end

  defp to_directive(%S.PushTag{} = s) do
    %D.PushTag{tag: s.tag}
  end

  defp to_directive(%S.PopTag{} = s) do
    %D.PopTag{tag: s.tag}
  end

  defp to_directive(%S.Query{} = s) do
    %D.Query{date: s.date, name: s.name, bql: s.bql, metadata: decode_meta(s.metadata)}
  end

  defp posting_to_directive(%S.Posting{} = p) do
    %D.Posting{
      account: p.account,
      amount: p.amount,
      currency: p.currency,
      cost: cost_to_directive(p.cost),
      price: price_to_directive(p.price),
      flag: p.flag,
      metadata: decode_meta(p.metadata)
    }
  end

  defp cost_to_directive(nil), do: nil

  defp cost_to_directive(%S.CostSpec{} = c) do
    %Beancount.CostSpec{
      per_amount: c.per_amount,
      per_currency: c.per_currency,
      total_amount: c.total_amount,
      total_currency: c.total_currency,
      date: c.date,
      label: c.label,
      merge: c.merge
    }
  end

  # -- Directive struct -> Schema --

  defp to_schema(%D.Open{} = d, i) do
    %S.Open{
      date: d.date,
      account: d.account,
      currencies: d.currencies,
      booking: d.booking,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Close{} = d, i) do
    %S.Close{date: d.date, account: d.account, metadata: encode_meta(d.metadata), file_order: i}
  end

  defp to_schema(%D.Commodity{} = d, i) do
    %S.Commodity{
      date: d.date,
      currency: d.currency,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Transaction{} = d, i) do
    %S.Transaction{
      date: d.date,
      flag: d.flag,
      payee: d.payee,
      narration: d.narration,
      tags: d.tags,
      links: d.links,
      metadata: encode_meta(d.metadata),
      file_order: i,
      postings: Enum.map(d.postings, &posting_to_schema/1)
    }
  end

  defp to_schema(%D.Balance{} = d, i) do
    %S.Balance{
      date: d.date,
      account: d.account,
      amount: d.amount,
      currency: d.currency,
      tolerance: d.tolerance,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Price{} = d, i) do
    %S.Price{
      date: d.date,
      commodity: d.commodity,
      amount: d.amount,
      currency: d.currency,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Note{} = d, i) do
    %S.Note{
      date: d.date,
      account: d.account,
      comment: d.comment,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Document{} = d, i) do
    %S.Document{
      date: d.date,
      account: d.account,
      path: d.path,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Event{} = d, i) do
    %S.Event{
      date: d.date,
      type: d.type,
      description: d.description,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Custom{} = d, i) do
    %S.Custom{
      date: d.date,
      type: d.type,
      values: serialize_values(d.values),
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Pad{} = d, i) do
    %S.Pad{
      date: d.date,
      account: d.account,
      source_account: d.source_account,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp to_schema(%D.Include{} = d, i) do
    %S.Include{path: d.path, file_order: i}
  end

  defp to_schema(%D.Option{} = d, i) do
    %S.Option{name: d.name, value: encode_scalar(d.value), file_order: i}
  end

  defp to_schema(%D.Plugin{} = d, i) do
    %S.Plugin{module: d.module, config: d.config, file_order: i}
  end

  defp to_schema(%D.PushTag{} = d, i) do
    %S.PushTag{tag: d.tag, file_order: i}
  end

  defp to_schema(%D.PopTag{} = d, i) do
    %S.PopTag{tag: d.tag, file_order: i}
  end

  defp to_schema(%D.Query{} = d, i) do
    %S.Query{
      date: d.date,
      name: d.name,
      bql: d.bql,
      metadata: encode_meta(d.metadata),
      file_order: i
    }
  end

  defp posting_to_schema(%D.Posting{} = p) do
    %S.Posting{
      account: p.account,
      amount: p.amount,
      currency: p.currency,
      cost: cost_to_schema(p.cost),
      price: price_to_schema(p.price),
      flag: p.flag,
      metadata: encode_meta(p.metadata)
    }
  end

  defp cost_to_schema(nil), do: nil

  defp cost_to_schema(%Beancount.CostSpec{} = c) do
    %S.CostSpec{
      per_amount: c.per_amount,
      per_currency: c.per_currency,
      total_amount: c.total_amount,
      total_currency: c.total_currency,
      date: c.date,
      label: c.label,
      merge: c.merge
    }
  end

  # -- Price annotation <-> embedded schema --

  defp price_to_schema(nil), do: nil

  defp price_to_schema(%{amount: amount, currency: currency} = price) do
    %S.PriceAnnotation{
      amount: amount,
      currency: currency,
      type: price |> Map.get(:type, :unit) |> Atom.to_string()
    }
  end

  defp price_to_directive(nil), do: nil

  defp price_to_directive(%S.PriceAnnotation{amount: amount, currency: currency, type: type}) do
    %{amount: amount, currency: currency, type: price_type(type)}
  end

  defp price_type("total"), do: :total
  defp price_type(_unit), do: :unit

  # -- Typed scalar codec (custom values, option values, metadata values) --

  defp serialize_values(nil), do: []
  defp serialize_values(values) when is_list(values), do: Enum.map(values, &encode_scalar/1)

  defp decode_values(nil), do: []
  defp decode_values(values) when is_list(values), do: Enum.map(values, &decode_scalar/1)

  defp encode_meta(nil), do: %{}

  defp encode_meta(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), encode_scalar(value)} end)

  defp decode_meta(nil), do: %{}

  defp decode_meta(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, decode_scalar(value)} end)

  defp encode_scalar(%Decimal{} = d),
    do: %{"type" => "decimal", "value" => Decimal.to_string(d)}

  defp encode_scalar(%Date{} = d), do: %{"type" => "date", "value" => Date.to_iso8601(d)}

  defp encode_scalar(%Beancount.Value.Account{name: n}),
    do: %{"type" => "account", "value" => n}

  defp encode_scalar(%Beancount.Value.Tag{name: n}), do: %{"type" => "tag", "value" => n}

  defp encode_scalar(%Beancount.Value.Amount{number: n, currency: c}),
    do: %{"type" => "amount", "value" => "#{Decimal.to_string(n)} #{c}"}

  defp encode_scalar(v) when is_binary(v), do: %{"type" => "string", "value" => v}
  defp encode_scalar(v) when is_boolean(v), do: %{"type" => "boolean", "value" => v}
  defp encode_scalar(v), do: %{"type" => "term", "value" => inspect(v)}

  defp decode_scalar(%{"type" => "decimal", "value" => v}), do: Decimal.new(v)
  defp decode_scalar(%{"type" => "date", "value" => v}), do: Date.from_iso8601!(v)

  defp decode_scalar(%{"type" => "account", "value" => v}),
    do: %Beancount.Value.Account{name: v}

  defp decode_scalar(%{"type" => "tag", "value" => v}), do: %Beancount.Value.Tag{name: v}

  defp decode_scalar(%{"type" => "amount", "value" => v}) do
    [number, currency] = String.split(v, " ", parts: 2)
    %Beancount.Value.Amount{number: Decimal.new(number), currency: currency}
  end

  defp decode_scalar(%{"type" => "string", "value" => v}), do: v
  defp decode_scalar(%{"type" => "boolean", "value" => v}), do: v
  defp decode_scalar(%{"type" => "term", "value" => v}), do: v
  # Legacy/untagged values (e.g. pre-existing rows) pass through unchanged.
  defp decode_scalar(v), do: v
end
