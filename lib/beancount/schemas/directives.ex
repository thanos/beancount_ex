defmodule Beancount.Schemas.Open do
  @moduledoc """
  Persisted `open` directive (table `beancount_opens`).

  Storage-layer counterpart of `Beancount.Directives.Open`. Rows are written by
  `Beancount.Storage.store/1` and rebuilt into directive structs by
  `Beancount.Storage.load/0`.

  ## Fields

    * `date` - the day the account opens.
    * `account` - colon-separated account name, e.g. `"Assets:Bank"`.
    * `currencies` - list of allowed commodity symbols, e.g. `["USD", "EUR"]`
      (`nil`/empty means any).
    * `booking` - booking method string (`"STRICT"`, `"FIFO"`, `"LIFO"`,
      `"AVERAGE"`, `"NONE"`), or `nil`.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Open{
        date: ~D[2026-01-01],
        account: "Assets:Bank",
        currencies: ["USD"],
        booking: nil,
        metadata: %{},
        file_order: 0
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_opens" do
    field(:date, :date)
    field(:account, :string)
    field(:currencies, {:array, :string})
    field(:booking, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Close do
  @moduledoc """
  Persisted `close` directive (table `beancount_closes`).

  Storage-layer counterpart of `Beancount.Directives.Close`.

  ## Fields

    * `date` - the day the account closes.
    * `account` - account being closed, e.g. `"Assets:Bank"`.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Close{
        date: ~D[2026-12-31],
        account: "Assets:Bank",
        metadata: %{},
        file_order: 5
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_closes" do
    field(:date, :date)
    field(:account, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Commodity do
  @moduledoc """
  Persisted `commodity` directive (table `beancount_commodities`).

  Storage-layer counterpart of `Beancount.Directives.Commodity`.

  ## Fields

    * `date` - declaration date of the commodity.
    * `currency` - commodity symbol, e.g. `"USD"` or `"AAPL"`.
    * `metadata` - arbitrary key/value map (e.g. `%{"name" => "Apple Inc."}`).
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Commodity{
        date: ~D[2026-01-01],
        currency: "AAPL",
        metadata: %{"name" => "Apple Inc."},
        file_order: 1
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_commodities" do
    field(:date, :date)
    field(:currency, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Balance do
  @moduledoc """
  Persisted `balance` assertion (table `beancount_balances`).

  Storage-layer counterpart of `Beancount.Directives.Balance`.

  ## Fields

    * `date` - the day the assertion is checked (start of day).
    * `account` - account whose balance is asserted.
    * `amount` - expected balance as `Decimal.t()`.
    * `currency` - commodity of the expected balance.
    * `tolerance` - optional `Decimal.t()` tolerance (`± amount`), or `nil`.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Balance{
        date: ~D[2026-06-01],
        account: "Assets:Bank",
        amount: Decimal.new("100"),
        currency: "USD",
        tolerance: nil,
        metadata: %{},
        file_order: 8
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_balances" do
    field(:date, :date)
    field(:account, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:tolerance, :decimal)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Price do
  @moduledoc """
  Persisted `price` directive (table `beancount_prices`).

  Storage-layer counterpart of `Beancount.Directives.Price`.

  ## Fields

    * `date` - the day the price holds.
    * `commodity` - the commodity being priced, e.g. `"AAPL"`.
    * `amount` - price as `Decimal.t()`.
    * `currency` - quote currency of `amount`, e.g. `"USD"`.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Price{
        date: ~D[2026-01-02],
        commodity: "AAPL",
        amount: Decimal.new("150"),
        currency: "USD",
        metadata: %{},
        file_order: 9
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_prices" do
    field(:date, :date)
    field(:commodity, :string)
    field(:amount, :decimal)
    field(:currency, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Note do
  @moduledoc """
  Persisted `note` directive (table `beancount_notes`).

  Storage-layer counterpart of `Beancount.Directives.Note`.

  ## Fields

    * `date` - the day the note is attached.
    * `account` - account the note is associated with.
    * `comment` - free-text note body.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Note{
        date: ~D[2026-01-03],
        account: "Assets:Bank",
        comment: "called the bank about the fee",
        metadata: %{},
        file_order: 10
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_notes" do
    field(:date, :date)
    field(:account, :string)
    field(:comment, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Document do
  @moduledoc """
  Persisted `document` directive (table `beancount_documents`).

  Storage-layer counterpart of `Beancount.Directives.Document`.

  ## Fields

    * `date` - the day the document is filed.
    * `account` - account the document belongs to.
    * `path` - filesystem path to the document.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Document{
        date: ~D[2026-01-04],
        account: "Assets:Bank",
        path: "/receipts/2026-01-04.pdf",
        metadata: %{},
        file_order: 11
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_documents" do
    field(:date, :date)
    field(:account, :string)
    field(:path, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Event do
  @moduledoc """
  Persisted `event` directive (table `beancount_events`).

  Storage-layer counterpart of `Beancount.Directives.Event`.

  ## Fields

    * `date` - the day the event value changes.
    * `type` - event name, e.g. `"location"` or `"employer"`.
    * `description` - the new value for the event.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Event{
        date: ~D[2026-01-05],
        type: "location",
        description: "Athens, GR",
        metadata: %{},
        file_order: 12
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_events" do
    field(:date, :date)
    field(:type, :string)
    field(:description, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Custom do
  @moduledoc """
  Persisted `custom` directive (table `beancount_customs`).

  Storage-layer counterpart of `Beancount.Directives.Custom`.

  ## Fields

    * `date` - the day of the custom entry.
    * `type` - custom directive type string, e.g. `"budget"`.
    * `values` - list of serialized value maps. `Beancount.Storage` encodes each
      value as `%{"type" => ..., "value" => ...}` so mixed value kinds
      (decimal, date, account, tag, amount, string, boolean) survive a JSON
      round-trip.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Custom{
        date: ~D[2026-01-06],
        type: "budget",
        values: [
          %{"type" => "string", "value" => "groceries"},
          %{"type" => "decimal", "value" => "500"}
        ],
        metadata: %{},
        file_order: 13
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_customs" do
    field(:date, :date)
    field(:type, :string)
    field(:values, {:array, :map})
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Pad do
  @moduledoc """
  Persisted `pad` directive (table `beancount_pads`).

  Storage-layer counterpart of `Beancount.Directives.Pad`.

  ## Fields

    * `date` - the day padding is allowed to take effect.
    * `account` - account to be padded.
    * `source_account` - account the padding transaction draws from
      (typically an `Equity:` account).
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Pad{
        date: ~D[2026-01-07],
        account: "Assets:Bank",
        source_account: "Equity:Opening-Balances",
        metadata: %{},
        file_order: 14
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_pads" do
    field(:date, :date)
    field(:account, :string)
    field(:source_account, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Include do
  @moduledoc """
  Persisted `include` directive (table `beancount_includes`).

  Storage-layer counterpart of `Beancount.Directives.Include`. This directive
  has no date.

  ## Fields

    * `path` - path to the included `.bean` file.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Include{path: "accounts/2026.bean", file_order: 0}

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_includes" do
    field(:path, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Option do
  @moduledoc """
  Persisted `option` directive (table `beancount_options`).

  Storage-layer counterpart of `Beancount.Directives.Option`. This directive
  has no date. The value is stored as a type-tagged map
  (`%{"type" => ..., "value" => ...}`) so that booleans, `Decimal`, and `Date`
  values round-trip without being flattened to strings.

  ## Fields

    * `name` - option key, e.g. `"operating_currency"`.
    * `value` - type-tagged option value map, e.g.
      `%{"type" => "string", "value" => "USD"}`.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Option{
        name: "operating_currency",
        value: %{"type" => "string", "value" => "USD"},
        file_order: 0
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_options" do
    field(:name, :string)
    field(:value, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Plugin do
  @moduledoc """
  Persisted `plugin` directive (table `beancount_plugins`).

  Storage-layer counterpart of `Beancount.Directives.Plugin`. This directive
  has no date.

  ## Fields

    * `module` - plugin module string, e.g. `"beancount.plugins.auto"`.
    * `config` - optional configuration string, or `nil`.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Plugin{
        module: "beancount.plugins.auto_accounts",
        config: nil,
        file_order: 1
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_plugins" do
    field(:module, :string)
    field(:config, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.PushTag do
  @moduledoc """
  Persisted `pushtag` directive (table `beancount_push_tags`).

  Storage-layer counterpart of `Beancount.Directives.PushTag`. This directive
  has no date; its position (`file_order`) determines the tag's scope.

  ## Fields

    * `tag` - tag name without the leading `#`, e.g. `"trip-athens"`.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.PushTag{tag: "trip-athens", file_order: 3}

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_push_tags" do
    field(:tag, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.PopTag do
  @moduledoc """
  Persisted `poptag` directive (table `beancount_pop_tags`).

  Storage-layer counterpart of `Beancount.Directives.PopTag`. This directive
  has no date; its position (`file_order`) determines where the tag scope ends.

  ## Fields

    * `tag` - tag name without the leading `#`, e.g. `"trip-athens"`.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.PopTag{tag: "trip-athens", file_order: 20}

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_pop_tags" do
    field(:tag, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Query do
  @moduledoc """
  Persisted `query` directive (table `beancount_queries`).

  Storage-layer counterpart of `Beancount.Directives.Query`.

  ## Fields

    * `date` - the day the named query is associated with.
    * `name` - query name, e.g. `"monthly-expenses"`.
    * `bql` - the BQL query string.
    * `metadata` - arbitrary key/value map.
    * `file_order` - zero-based position of the directive in the source.

  ## Example

      %Beancount.Schemas.Query{
        date: ~D[2026-01-08],
        name: "recent",
        bql: "SELECT date, account, position",
        metadata: %{},
        file_order: 15
      }

  """
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_queries" do
    field(:date, :date)
    field(:name, :string)
    field(:bql, :string)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end
