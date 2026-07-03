defmodule Beancount.CompareTest.UniqueCellA do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text),
    do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, bql), do: {:ok, row(bql, "n/a")}

  defp row(bql, cell) do
    if String.contains?(bql, "units(sum(position))") do
      %Beancount.Query.Result{
        columns: ["account", "units", "cost"],
        rows: [["Assets:Stocks", cell, ""]],
        raw: "",
        status: :ok
      }
    else
      %Beancount.Query.Result{
        columns: ["account", "balance"],
        rows: [["Assets:Stocks", cell]],
        raw: "",
        status: :ok
      }
    end
  end
end

defmodule Beancount.CompareTest.UniqueCellB do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text),
    do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, bql), do: {:ok, row(bql, "n/a")}

  defp row(bql, cell) do
    if String.contains?(bql, "units(sum(position))") do
      %Beancount.Query.Result{
        columns: ["account", "units", "cost"],
        rows: [["Assets:Stocks", cell, ""]],
        raw: "",
        status: :ok
      }
    else
      %Beancount.Query.Result{
        columns: ["account", "balance"],
        rows: [["Assets:Stocks", cell]],
        raw: "",
        status: :ok
      }
    end
  end
end

defmodule Beancount.CompareTest.PositionLotsA do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text),
    do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, bql), do: {:ok, query_result(bql, "15 AAPL {150 USD}")}

  defp query_result(bql, position) do
    cond do
      String.contains?(bql, "units(sum(position))") ->
        %Beancount.Query.Result{
          columns: ["account", "units", "cost"],
          rows: [["Assets:Stocks", position, "2250 USD"]],
          raw: "",
          status: :ok
        }

      String.contains?(bql, "Income|Expenses") ->
        %Beancount.Query.Result{columns: ["account", "balance"], rows: [], raw: "", status: :ok}

      true ->
        %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Assets:Stocks", position]],
          raw: "",
          status: :ok
        }
    end
  end
end

defmodule Beancount.CompareTest.PositionLotsB do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text),
    do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, bql), do: {:ok, query_result(bql, "15 AAPL {150 USD}, 0.00 USD")}

  defp query_result(bql, position) do
    cond do
      String.contains?(bql, "units(sum(position))") ->
        %Beancount.Query.Result{
          columns: ["account", "units", "cost"],
          rows: [["Assets:Stocks", position, "2250.00 USD"]],
          raw: "",
          status: :ok
        }

      String.contains?(bql, "Income|Expenses") ->
        %Beancount.Query.Result{columns: ["account", "balance"], rows: [], raw: "", status: :ok}

      true ->
        %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Assets:Stocks", position]],
          raw: "",
          status: :ok
        }
    end
  end
end

defmodule Beancount.CompareTest.QueryFormatA do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text),
    do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, bql), do: {:ok, query_result(bql, "5000.00 USD", "5000.00 USD")}

  defp query_result(bql, balance, cost) do
    cond do
      String.contains?(bql, "units(sum(position))") ->
        %Beancount.Query.Result{
          columns: ["account", "units", "cost"],
          rows: [["Assets:Bank", balance, cost]],
          raw: "",
          status: :ok
        }

      String.contains?(bql, "Income|Expenses") ->
        %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Income:Salary", "-5000.00 USD"]],
          raw: "",
          status: :ok
        }

      true ->
        %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Assets:Bank", balance]],
          raw: "",
          status: :ok
        }
    end
  end
end

defmodule Beancount.CompareTest.QueryFormatB do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text),
    do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, bql), do: {:ok, query_result(bql, "5000 USD", "5000 USD")}

  defp query_result(bql, balance, cost) do
    cond do
      String.contains?(bql, "units(sum(position))") ->
        %Beancount.Query.Result{
          columns: ["account", "units", "cost"],
          rows: [["Assets:Bank", balance, cost]],
          raw: "",
          status: :ok
        }

      String.contains?(bql, "Income|Expenses") ->
        %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Income:Salary", "-5000 USD"]],
          raw: "",
          status: :ok
        }

      true ->
        %Beancount.Query.Result{
          columns: ["account", "balance"],
          rows: [["Assets:Bank", balance]],
          raw: "",
          status: :ok
        }
    end
  end
end

defmodule Beancount.CompareTest.CLIContextOracle do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{
         status: :error,
         errors: [
           %{line: 3, message: "Balance failed for 'Assets:Foo': expected 2 USD"},
           %{line: nil, message: "2026-01-01 balance Assets:Foo  2 USD"},
           %{line: nil, message: "Assets:Cash    10 USD"}
         ]
       }
     }}
  end

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, _bql),
    do: {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}
end

defmodule Beancount.CompareTest.CLIContextNative do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{
         status: :error,
         errors: [%{line: 3, message: "Balance failed for 'Assets:Foo': expected 2 USD"}]
       }
     }}
  end

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, _bql),
    do: {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}
end

defmodule Beancount.CompareTest.OtherErrorA do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text), do: other_error("alpha unknown failure")

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, _bql),
    do: {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}

  defp other_error(message) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{status: :error, errors: [%{line: nil, message: message}]}
     }}
  end
end

defmodule Beancount.CompareTest.OtherErrorB do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text), do: other_error("beta unknown failure")

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, _bql),
    do: {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}

  defp other_error(message) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{status: :error, errors: [%{line: nil, message: message}]}
     }}
  end
end

defmodule Beancount.CompareTest.BookingInsufficientCLI do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text), do: booking_error("Not enough lots to reduce")

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, _bql),
    do: {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}

  defp booking_error(message) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{status: :error, errors: [%{line: 1, message: message}]}
     }}
  end
end

defmodule Beancount.CompareTest.BookingInsufficientNative do
  @moduledoc false
  @behaviour Beancount.Engine

  @impl true
  def render(_directives), do: ""

  @impl true
  def check(_text), do: booking_error("Insufficient units for reduction")

  @impl true
  def check_file(_path), do: check("")

  @impl true
  def query(_text, _bql),
    do: {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}

  defp booking_error(message) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{status: :error, errors: [%{line: 1, message: message}]}
     }}
  end
end

defmodule Beancount.CompareTest.PlainAmountA do
  @moduledoc false
  @behaviour Beancount.Engine
  @impl true
  def render(_), do: ""
  @impl true
  def check(_), do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}
  @impl true
  def check_file(_), do: check("")
  @impl true
  def query(_, _),
    do:
      {:ok,
       %Beancount.Query.Result{
         columns: ["account", "balance"],
         rows: [["Assets:Bank", "5000.00 USD"]],
         raw: "",
         status: :ok
       }}
end

defmodule Beancount.CompareTest.PlainAmountB do
  @moduledoc false
  @behaviour Beancount.Engine
  @impl true
  def render(_), do: ""
  @impl true
  def check(_), do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}
  @impl true
  def check_file(_), do: check("")
  @impl true
  def query(_, _),
    do:
      {:ok,
       %Beancount.Query.Result{
         columns: ["account", "balance"],
         rows: [["Assets:Bank", "5000 USD"]],
         raw: "",
         status: :ok
       }}
end

defmodule Beancount.CompareTest.ZeroBalanceA do
  @moduledoc false
  @behaviour Beancount.Engine
  @impl true
  def render(_), do: ""
  @impl true
  def check(_), do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}
  @impl true
  def check_file(_), do: check("")
  @impl true
  def query(_, _),
    do:
      {:ok,
       %Beancount.Query.Result{
         columns: ["account", "balance"],
         rows: [["Assets:Bank", "5000 USD"], ["Assets:Empty", "0 USD"]],
         raw: "",
         status: :ok
       }}
end

defmodule Beancount.CompareTest.ZeroBalanceB do
  @moduledoc false
  @behaviour Beancount.Engine
  @impl true
  def render(_), do: ""
  @impl true
  def check(_), do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}
  @impl true
  def check_file(_), do: check("")
  @impl true
  def query(_, _),
    do:
      {:ok,
       %Beancount.Query.Result{
         columns: ["account", "balance"],
         rows: [["Assets:Bank", "5000 USD"], ["Assets:Empty", ""]],
         raw: "",
         status: :ok
       }}
end

defmodule Beancount.CompareTest.CostLotA do
  @moduledoc false
  @behaviour Beancount.Engine
  @impl true
  def render(_), do: ""
  @impl true
  def check(_), do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}
  @impl true
  def check_file(_), do: check("")
  @impl true
  def query(_, _),
    do:
      {:ok,
       %Beancount.Query.Result{
         columns: ["account", "balance"],
         rows: [["Assets:Stocks", "5 AAPL {150 USD}, 5 AAPL {150 USD}"]],
         raw: "",
         status: :ok
       }}
end

defmodule Beancount.CompareTest.CostLotB do
  @moduledoc false
  @behaviour Beancount.Engine
  @impl true
  def render(_), do: ""
  @impl true
  def check(_), do: {:ok, %Beancount.Result{status: :ok, normalized: %{status: :ok, errors: []}}}
  @impl true
  def check_file(_), do: check("")
  @impl true
  def query(_, _),
    do:
      {:ok,
       %Beancount.Query.Result{
         columns: ["account", "balance"],
         rows: [["Assets:Stocks", "10 AAPL {150 USD}"]],
         raw: "",
         status: :ok
       }}
end
