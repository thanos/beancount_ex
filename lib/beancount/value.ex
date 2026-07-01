defmodule Beancount.Value do
  @moduledoc """
  Typed scalar values for `Beancount.Directives.Custom` and metadata.

  Wrap accounts, tags, and amounts so the renderer emits correct Beancount
  syntax inside `custom` directive values.
  """

  defmodule Account do
    @moduledoc """
    An account name for `custom` directive values.

    ## Beancount syntax

        Expenses:Food

    ## Elixir struct

        %Beancount.Value.Account{name: "Expenses:Food"}

    Or use `Beancount.account_value/1`:

        Beancount.account_value("Expenses:Food")

    ## Fields

      * `name` - colon-separated account string rendered as a bareword.
    """

    defstruct [:name]

    @type t :: %__MODULE__{name: String.t()}
  end

  defmodule Tag do
    @moduledoc """
    A tag for `custom` directive values.

    ## Beancount syntax

        #monthly

    ## Elixir struct

        %Beancount.Value.Tag{name: "monthly"}

    Or use `Beancount.tag_value/1`:

        Beancount.tag_value("monthly")

    ## Fields

      * `name` - tag without `#` (rendered as `#name`).
    """

    defstruct [:name]

    @type t :: %__MODULE__{name: String.t()}
  end

  defmodule Amount do
    @moduledoc """
    A commodity amount for `custom` directive values.

    ## Beancount syntax

        400.00 USD

    ## Elixir struct

        %Beancount.Value.Amount{
          number: Decimal.new("400.00"),
          currency: "USD"
        }

    Or use `Beancount.amount_value/2`:

        Beancount.amount_value(Decimal.new("400.00"), "USD")

    ## Fields

      * `number` - `Decimal.t()` quantity (unsigned in custom values).
      * `currency` - commodity symbol.
    """

    defstruct [:number, :currency]

    @type t :: %__MODULE__{number: Decimal.t(), currency: String.t()}
  end
end
