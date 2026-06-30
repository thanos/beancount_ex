defmodule Beancount.IntegrationTest do
  @moduledoc """
  Tests that require a real Beancount (`bean-check`) installation.

  These are excluded by default. Run them with:

      mix test --include beancount

  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Beancount.{Checker, Golden}

  @moduletag :integration
  @moduletag :beancount

  setup do
    unless Checker.available?() do
      raise "bean-check not available; install Beancount to run integration tests"
    end

    :ok
  end

  test "a valid ledger passes bean-check" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
      ])
    ]

    assert {:ok, %Beancount.Result{status: :ok, exit_status: 0}} = Beancount.check(ledger)
  end

  test "an unbalanced transaction fails bean-check" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-4000"), "USD")
      ])
    ]

    assert {:error, %Beancount.Result{status: :error}} = Beancount.check(ledger)
  end

  property "generated ledgers pass bean-check" do
    check all(ledger <- Beancount.Property.ledger(), max_runs: 25) do
      assert {:ok, %Beancount.Result{status: :ok}} = Beancount.check(ledger)
    end
  end

  for case_dir <- Beancount.Golden.cases() do
    @case_dir case_dir
    @name Path.basename(case_dir)

    test "golden normalized result matches for #{@name}" do
      expected = Golden.expected_result(@case_dir)

      if expected do
        {_status, result} = Beancount.check_text(Golden.render(@case_dir))
        actual = result.normalized |> Jason.encode!() |> Jason.decode!()
        assert actual == expected
      end
    end
  end
end
