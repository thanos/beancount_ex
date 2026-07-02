defmodule Beancount.Storage do
  @moduledoc """
  Storage and import/export for Beancount directives via Ecto.

  The default backend is SQLite in-memory (`:memory:`). For persistence,
  configure a file path:

      config :beancount_ex, Beancount.Repo, database: "ledger.db"

  ## Import / Export

      Beancount.Storage.import_file("ledger.bean")
      Beancount.Storage.export_file("out.bean")

  Future backends: PostgreSQL (via `postgrex`), Mnesia (via `ecto_mnesia`).
  """
  alias Beancount.Directives, as: D
  alias Beancount.{Parser, Renderer, Repo}
  alias Beancount.Schemas, as: S

  @doc "Import directives from a .bean file into the database."
  @spec import_file(Path.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def import_file(path) do
    with {:ok, text} <- File.read(path),
         {:ok, directives} <- Parser.parse_text(text) do
      store(directives)
    end
  end

  @doc "Store a list of directives into the database."
  @spec store([Beancount.Directive.t()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def store(directives) do
    Repo.transaction(fn ->
      clear()

      Enum.each(Enum.with_index(directives), fn {directive, index} ->
        insert_directive(directive, index)
      end)

      length(directives)
    end)
  end

  @doc "Load all directives from the database, ordered by file_order."
  @spec load() :: [Beancount.Directive.t()]
  def load do
    import Ecto.Query

    tables()
    |> Enum.flat_map(fn {schema, _table} ->
      schema
      |> from(order_by: :file_order)
      |> Repo.all()
      |> Enum.map(&to_directive/1)
    end)
    |> Enum.sort_by(fn
      %{date: %Date{} = d} -> {1, Date.to_iso8601(d), 0}
      _ -> {0, "0000-01-01", 0}
    end)
  end

  @doc "Export all directives from the database to a .bean file."
  @spec export_file(Path.t()) :: :ok | {:error, term()}
  def export_file(path) do
    directives = load()
    File.write(path, Renderer.render(directives))
  end

  @doc "Clear all directives from the database."
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

  defp insert_directive(_, _i), do: :ok

  # -- Schema -> Directive struct --

  defp to_directive(%S.Open{} = s) do
    %D.Open{
      date: s.date,
      account: s.account,
      currencies: s.currencies || [],
      booking: s.booking,
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Close{} = s) do
    %D.Close{date: s.date, account: s.account, metadata: s.metadata || %{}}
  end

  defp to_directive(%S.Commodity{} = s) do
    %D.Commodity{date: s.date, currency: s.currency, metadata: s.metadata || %{}}
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
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Balance{} = s) do
    %D.Balance{
      date: s.date,
      account: s.account,
      amount: s.amount,
      currency: s.currency,
      tolerance: s.tolerance,
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Price{} = s) do
    %D.Price{
      date: s.date,
      commodity: s.commodity,
      amount: s.amount,
      currency: s.currency,
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Note{} = s) do
    %D.Note{date: s.date, account: s.account, comment: s.comment, metadata: s.metadata || %{}}
  end

  defp to_directive(%S.Document{} = s) do
    %D.Document{date: s.date, account: s.account, path: s.path, metadata: s.metadata || %{}}
  end

  defp to_directive(%S.Event{} = s) do
    %D.Event{
      date: s.date,
      type: s.type,
      description: s.description,
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Custom{} = s) do
    %D.Custom{
      date: s.date,
      type: s.type,
      values: s.values || [],
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Pad{} = s) do
    %D.Pad{
      date: s.date,
      account: s.account,
      source_account: s.source_account,
      metadata: s.metadata || %{}
    }
  end

  defp to_directive(%S.Include{} = s) do
    %D.Include{path: s.path}
  end

  defp to_directive(%S.Option{} = s) do
    %D.Option{name: s.name, value: s.value}
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
    %D.Query{date: s.date, name: s.name, bql: s.bql, metadata: s.metadata || %{}}
  end

  defp posting_to_directive(%S.Posting{} = p) do
    %D.Posting{
      account: p.account,
      amount: p.amount,
      currency: p.currency,
      cost: cost_to_directive(p.cost),
      price: p.price,
      flag: p.flag,
      metadata: p.metadata || %{}
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
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Close{} = d, i) do
    %S.Close{date: d.date, account: d.account, metadata: d.metadata, file_order: i}
  end

  defp to_schema(%D.Commodity{} = d, i) do
    %S.Commodity{date: d.date, currency: d.currency, metadata: d.metadata, file_order: i}
  end

  defp to_schema(%D.Transaction{} = d, i) do
    %S.Transaction{
      date: d.date,
      flag: d.flag,
      payee: d.payee,
      narration: d.narration,
      tags: d.tags,
      links: d.links,
      metadata: d.metadata,
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
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Price{} = d, i) do
    %S.Price{
      date: d.date,
      commodity: d.commodity,
      amount: d.amount,
      currency: d.currency,
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Note{} = d, i) do
    %S.Note{
      date: d.date,
      account: d.account,
      comment: d.comment,
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Document{} = d, i) do
    %S.Document{
      date: d.date,
      account: d.account,
      path: d.path,
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Event{} = d, i) do
    %S.Event{
      date: d.date,
      type: d.type,
      description: d.description,
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Custom{} = d, i) do
    %S.Custom{
      date: d.date,
      type: d.type,
      values: serialize_values(d.values),
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Pad{} = d, i) do
    %S.Pad{
      date: d.date,
      account: d.account,
      source_account: d.source_account,
      metadata: d.metadata,
      file_order: i
    }
  end

  defp to_schema(%D.Include{} = d, i) do
    %S.Include{path: d.path, file_order: i}
  end

  defp to_schema(%D.Option{} = d, i) do
    %S.Option{name: d.name, value: to_string(d.value), file_order: i}
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
    %S.Query{date: d.date, name: d.name, bql: d.bql, metadata: d.metadata, file_order: i}
  end

  defp posting_to_schema(%D.Posting{} = p) do
    %S.Posting{
      account: p.account,
      amount: p.amount,
      currency: p.currency,
      cost: cost_to_schema(p.cost),
      price: p.price,
      flag: p.flag,
      metadata: p.metadata
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

  defp serialize_values(values) when is_list(values) do
    Enum.map(values, &serialize_value/1)
  end

  defp serialize_value(%Decimal{} = d),
    do: %{"type" => "decimal", "value" => Decimal.to_string(d)}

  defp serialize_value(%Date{} = d), do: %{"type" => "date", "value" => Date.to_iso8601(d)}

  defp serialize_value(%Beancount.Value.Account{name: n}),
    do: %{"type" => "account", "value" => n}

  defp serialize_value(%Beancount.Value.Tag{name: n}), do: %{"type" => "tag", "value" => n}

  defp serialize_value(%Beancount.Value.Amount{number: n, currency: c}),
    do: %{"type" => "amount", "value" => "#{Decimal.to_string(n)} #{c}"}

  defp serialize_value(v) when is_binary(v), do: %{"type" => "string", "value" => v}
  defp serialize_value(v) when is_boolean(v), do: %{"type" => "boolean", "value" => v}
  defp serialize_value(v), do: %{"type" => "term", "value" => inspect(v)}
end
