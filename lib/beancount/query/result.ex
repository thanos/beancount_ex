defmodule Beancount.Query.Result do
  @moduledoc """
  Neutral, engine-independent result of a BQL query.

  Like `Beancount.Result`, this struct is populated identically by the CLI
  engine today and by any future native engine, so query output can be compared
  across backends (see `Beancount.Compare` and the oracle strategy guide).

  Fields:

    * `:columns` - ordered list of column names.
    * `:rows` - list of rows; each row is a list of string cells aligned with
      `:columns`. Values are kept as raw strings here; higher-level helpers
      (`Beancount.Report`) and the optional Explorer bridge handle typing.
    * `:raw` - the raw output (CSV) returned by the engine, for debugging.
    * `:status` - always `:ok` for a successful query.
  """

  @derive {Jason.Encoder, only: [:columns, :rows, :raw, :status]}
  defstruct columns: [], rows: [], raw: "", status: :ok

  @type row :: [String.t()]

  @type t :: %__MODULE__{
          columns: [String.t()],
          rows: [row()],
          raw: binary(),
          status: :ok
        }

  @doc """
  Convert the result into a list of maps keyed by column name.

  ## Examples

      iex> result = %Beancount.Query.Result{
      ...>   columns: ["account", "balance"],
      ...>   rows: [["Assets:Bank", "5000 USD"]]
      ...> }
      iex> Beancount.Query.Result.to_maps(result)
      [%{"account" => "Assets:Bank", "balance" => "5000 USD"}]

  """
  @spec to_maps(t()) :: [map()]
  def to_maps(%__MODULE__{columns: columns, rows: rows}) do
    Enum.map(rows, fn row -> columns |> Enum.zip(row) |> Map.new() end)
  end
end
