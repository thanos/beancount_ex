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

  test "compare/3 ignores bean-check context lines in other_errors" do
    ledger = Beancount.render(@ledger)

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.CLIContextOracle,
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
