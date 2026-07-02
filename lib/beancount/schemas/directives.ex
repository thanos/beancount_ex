defmodule Beancount.Schemas.Open do
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
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_customs" do
    field(:date, :date)
    field(:type, :string)
    field(:values, :map)
    field(:metadata, :map)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Pad do
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
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_includes" do
    field(:path, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Option do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_options" do
    field(:name, :string)
    field(:value, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Plugin do
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
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_push_tags" do
    field(:tag, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.PopTag do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "beancount_pop_tags" do
    field(:tag, :string)
    field(:file_order, :integer)
    timestamps()
  end
end

defmodule Beancount.Schemas.Query do
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
