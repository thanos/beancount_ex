defmodule Beancount.Directives.Include do
  @moduledoc """
  The `include` directive pulls another ledger file into the current one.

  See [Includes](https://beancount.github.io/docs/beancount_language_syntax/#includes).

  ## Beancount syntax

      include "accounts/checking.bean"

  General form: `include "Path"`

  This directive has no date. Place it at the top of a directive list, before
  dated entries, to mirror real Beancount file layout.

  ## Elixir struct

      %Beancount.Directives.Include{
        path: "accounts/checking.bean"
      }

  Or use `Beancount.include/1`:

      Beancount.include("accounts/checking.bean")

  ## Fields

    * `path` - relative or absolute path to another `.bean` file. Rendered as a
      quoted string.
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
