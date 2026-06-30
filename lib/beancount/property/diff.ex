defmodule Beancount.Property.Diff do
  @moduledoc """
  Structured difference between oracle and native engine results.
  """

  defstruct callback: nil, oracle: nil, native: nil, message: nil

  @type t :: %__MODULE__{
          callback: :check | :query | nil,
          oracle: term(),
          native: term(),
          message: String.t() | nil
        }
end
