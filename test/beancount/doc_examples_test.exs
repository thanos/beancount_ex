defmodule Beancount.BQLDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.BQL
end

defmodule Beancount.ParserDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.Parser
end

defmodule Beancount.ReportDocTest do
  use ExUnit.Case, async: false

  setup do
    original = Application.get_env(:beancount_ex, :engine)
    on_exit(fn -> Application.put_env(:beancount_ex, :engine, original) end)
    :ok
  end

  doctest Beancount.Report
end

defmodule Beancount.QueryDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.Query
end

defmodule Beancount.CompareDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.Compare
end

defmodule Beancount.EngineDocTest do
  use ExUnit.Case, async: false

  setup do
    original = Application.get_env(:beancount_ex, :engine)
    on_exit(fn -> Application.put_env(:beancount_ex, :engine, original) end)
    :ok
  end

  doctest Beancount.Engine
  doctest Beancount.Engine.CLI, only: [render: 1]
  doctest Beancount.Engine.Elixir
end

defmodule Beancount.CostSpecDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.CostSpec
end

defmodule Beancount.DirectiveDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.Directive
end

defmodule Beancount.PropertyDocTest do
  use ExUnit.Case, async: true
  doctest Beancount.Property
end
