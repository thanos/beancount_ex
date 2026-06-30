defmodule Beancount.Directives.Include do
  @moduledoc """
  The `include` directive pulls another ledger file into the current one.

      include "accounts/checking.bean"

  This directive has no date. Place it at the top of a directive list, before
  dated entries, to mirror real Beancount file layout.
  """

  alias Beancount.Renderer

  @enforce_keys [:path]
  defstruct path: nil

  @type t :: %__MODULE__{path: String.t()}

  defimpl Beancount.Directive do
    def to_bean(%{path: path}) do
      "include " <> Renderer.quote_string(path)
    end
  end
end
