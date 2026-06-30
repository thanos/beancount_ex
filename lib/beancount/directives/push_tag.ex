defmodule Beancount.Directives.PushTag do
  @moduledoc """
  The `pushtag` directive pushes a tag onto Beancount's tag stack.

      pushtag #trip

  """

  @enforce_keys [:tag]
  defstruct tag: nil

  @type t :: %__MODULE__{tag: String.t()}

  defimpl Beancount.Directive do
    def to_bean(%{tag: tag}) do
      "pushtag #" <> tag
    end
  end
end
