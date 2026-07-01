defmodule Beancount.Engine.Elixir.Lot do
  @moduledoc false

  alias Beancount.CostSpec

  @enforce_keys [:units, :currency]
  defstruct units: nil, currency: nil, cost: nil

  @type t :: %__MODULE__{
          units: Decimal.t(),
          currency: String.t(),
          cost: CostSpec.t() | nil
        }
end
