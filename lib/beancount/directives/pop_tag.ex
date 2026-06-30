defmodule Beancount.Directives.PopTag do
  @moduledoc """
  The `poptag` directive pops a tag from Beancount's tag stack.

      poptag #trip

  """

  @enforce_keys [:tag]
  defstruct tag: nil

  @type t :: %__MODULE__{tag: String.t()}

  defimpl Beancount.Directive do
    def to_bean(%{tag: tag}) do
      "poptag #" <> tag
    end
  end
end
