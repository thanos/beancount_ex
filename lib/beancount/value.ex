defmodule Beancount.Value do
  @moduledoc """
  Typed scalar values for `custom` directives and metadata.

  Beancount custom entries can carry accounts, tags, and amounts in addition
  to plain strings and numbers. Wrap those values so the renderer emits the
  correct bareword or prefixed syntax.
  """

  defmodule Account do
    @moduledoc "An account name rendered as a bareword, e.g. `Expenses:Food`."
    defstruct [:name]
  end

  defmodule Tag do
    @moduledoc "A tag rendered with a leading `#`, e.g. `#trip`."
    defstruct [:name]
  end

  defmodule Amount do
    @moduledoc "A commodity amount rendered as `NUMBER CURRENCY`."
    defstruct [:number, :currency]
  end
end
