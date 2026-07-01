defmodule Beancount.BQL.AST do
  @moduledoc false

  defmodule Query do
    @moduledoc false
    @enforce_keys [:select]
    defstruct select: [], where: nil, group_by: [], order_by: [], limit: nil

    @type t :: %__MODULE__{
            select: [Beancount.BQL.AST.Column.t()],
            where: Beancount.BQL.AST.expr() | nil,
            group_by: [Beancount.BQL.AST.expr()],
            order_by: [Beancount.BQL.AST.Order.t()],
            limit: non_neg_integer() | nil
          }
  end

  defmodule Column do
    @moduledoc false
    defstruct expr: nil, as: nil

    @type t :: %__MODULE__{
            expr: Beancount.BQL.AST.expr(),
            as: String.t() | nil
          }
  end

  defmodule Order do
    @moduledoc false
    defstruct expr: nil, direction: :asc

    @type t :: %__MODULE__{
            expr: Beancount.BQL.AST.expr(),
            direction: :asc | :desc
          }
  end

  @type expr ::
          {:ident, String.t()}
          | {:string, String.t()}
          | {:number, Decimal.t()}
          | {:func, atom(), [expr()]}
          | {:unary, :not, expr()}
          | {:binary, atom(), expr(), expr()}

  @type t :: expr()
end
