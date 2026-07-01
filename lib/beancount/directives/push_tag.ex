defmodule Beancount.Directives.PushTag do
  @moduledoc """
  The `pushtag` directive pushes a tag onto Beancount's tag stack.

  See [The Tag Stack](https://beancount.github.io/docs/beancount_language_syntax/#the-tag-stack).

  ## Beancount syntax

      pushtag #trip

  General form: `pushtag #Tag`

  Tags pushed here are automatically applied to following transactions until
  a matching `poptag`.

  ## Elixir struct

      %Beancount.Directives.PushTag{
        tag: "trip"
      }

  Or use `Beancount.push_tag/1`:

      Beancount.push_tag("trip")

  ## Fields

    * `tag` - tag name without the `#` prefix (rendered as `pushtag #trip`).
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
