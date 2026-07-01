defmodule Beancount.Directives.PopTag do
  @moduledoc """
  The `poptag` directive pops a tag from Beancount's tag stack.

  See [The Tag Stack](https://beancount.github.io/docs/beancount_language_syntax/#the-tag-stack).

  ## Beancount syntax

      poptag #trip

  General form: `poptag #Tag`

  ## Elixir struct

      %Beancount.Directives.PopTag{
        tag: "trip"
      }

  Or use `Beancount.pop_tag/1`:

      Beancount.pop_tag("trip")

  ## Fields

    * `tag` - tag name without the `#` prefix (must match a prior `pushtag`).
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
