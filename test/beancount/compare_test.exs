defmodule Beancount.CompareTest do
  use ExUnit.Case, async: false

  setup do
    case Beancount.FakeEngine.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    try do
      Beancount.FakeEngine.reset!()
    catch
      :exit, _ ->
        {:ok, _} = Beancount.FakeEngine.start_link()
        Beancount.FakeEngine.reset!()
    end

    :ok
  end

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
    ])
  ]

  test "compare/3 reports equivalent engines as equivalent" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.Engine.Elixir,
               @ledger
             )
  end

  test "compare/3 accepts binary ledger text" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.Engine.Elixir,
               Beancount.render(@ledger)
             )
  end

  test "compare/3 reports equivalent engines for pad ledgers" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.Engine.Elixir,
               """
               2026-01-01 open Assets:Cash USD
               2026-01-01 open Equity:Opening
               2026-01-02 pad Assets:Cash Equity:Opening
               2026-01-03 balance Assets:Cash  5 USD
               """
             )
  end

  test "compare/3 returns a structured diff on query mismatch" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: message}} =
             Beancount.Compare.compare(
               Beancount.FakeEngine,
               Beancount.Engine.Elixir,
               @ledger
             )

    assert message =~ "query"
  end

  test "compare/3 returns a structured diff on check mismatch" do
    broken = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Income:Salary USD

    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -4000 USD
    """

    assert {:error, %Beancount.Property.Diff{callback: :check, message: message}} =
             Beancount.Compare.compare(
               Beancount.FakeEngine,
               Beancount.Engine.Elixir,
               broken
             )

    assert message =~ "check"
  end

  test "compare/3 normalizes equivalent query rows with different lot formatting" do
    ledger = Beancount.render(@ledger)

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.QueryFormatA,
               Beancount.CompareTest.QueryFormatB,
               ledger
             )
  end

  test "compare/3 normalizes merged cost lots and zero positions" do
    stocks_ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"])
    ]

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.PositionLotsA,
               Beancount.CompareTest.PositionLotsB,
               stocks_ledger
             )
  end

  test "compare/3 ignores bean-check context lines in other_errors" do
    ledger = Beancount.render(@ledger)

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.CLIContextOracle,
               Beancount.CompareTest.CLIContextNative,
               ledger
             )
  end

  test "compare/3 treats uncategorized errors on one side as non-equivalent" do
    ledger = Beancount.render(@ledger)

    assert {:error, %Beancount.Property.Diff{callback: :check}} =
             Beancount.Compare.compare(
               Beancount.CompareTest.OtherErrorA,
               Beancount.CompareTest.CLIContextNative,
               ledger
             )
  end

  test "compare/3 rejects different uncategorized errors" do
    ledger = Beancount.render(@ledger)

    assert {:error, %Beancount.Property.Diff{callback: :check}} =
             Beancount.Compare.compare(
               Beancount.CompareTest.OtherErrorA,
               Beancount.CompareTest.OtherErrorB,
               ledger
             )
  end

  test "compare/3 treats booking insufficient errors as equivalent" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.BookingInsufficientCLI,
               Beancount.CompareTest.BookingInsufficientNative,
               Beancount.Golden.render(
                 Path.join(Beancount.Golden.root(), "booking_spec_too_small")
               )
             )
  end

  test "compare/3 returns query diff when an engine fails a canned query" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: "query failed"}} =
             Beancount.Compare.compare(
               Beancount.BrokenQueryEngine,
               Beancount.Engine.Elixir,
               @ledger
             )
  end

  test "compare/3 normalizes unique non-position cells" do
    stocks_ledger = [Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"])]

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.UniqueCellA,
               Beancount.CompareTest.UniqueCellB,
               stocks_ledger
             )
  end

  test "compare/3 reports query failures from an engine" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: "query failed"}} =
             Beancount.Compare.compare(
               Beancount.BrokenQueryEngine,
               Beancount.Engine.Elixir,
               @ledger
             )

    assert {:error, %Beancount.Property.Diff{callback: :query, message: "query failed"}} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.BrokenQueryEngine,
               @ledger
             )
  end

  test "BrokenQueryEngine implements check and check_file" do
    assert Beancount.BrokenQueryEngine.render([]) == ""

    assert {:ok, %Beancount.Result{status: :ok}} =
             Beancount.BrokenQueryEngine.check(Beancount.render(@ledger))

    path = Path.join(System.tmp_dir!(), "compare_#{System.unique_integer([:positive])}.bean")
    File.write!(path, Beancount.render(@ledger))
    on_exit(fn -> File.rm(path) end)

    assert {:ok, %Beancount.Result{status: :ok}} = Beancount.BrokenQueryEngine.check_file(path)

    assert {:error, %Beancount.Result{status: :error}} =
             Beancount.BrokenQueryEngine.query("ledger", "SELECT account")
  end
end

defmodule Beancount.CompareTest.UniqueCellA do
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
