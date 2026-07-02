defmodule Beancount.StorageDocTest do
  @moduledoc """
  Guards `Beancount.Storage` moduledoc examples (shared DB; not plain doctests).
  """
  use ExUnit.Case, async: false

  alias Beancount.{Queries, Storage}

  setup do
    Storage.clear()
    on_exit(fn -> Storage.clear() end)
    :ok
  end

  test "store/1 and load/0 example from moduledoc" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ])
    ]

    assert {:ok, 2} = Storage.store(ledger)

    [%Beancount.Directives.Open{account: "Assets:Bank"} | _] = Storage.load()
  end

  test "clear/0 example from moduledoc" do
    Storage.store([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
    assert :ok = Storage.clear()
    assert Storage.load() == []
  end

  test "export_file/1 round-trips rendered text" do
    ledger = [Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])]
    {:ok, _} = Storage.store(ledger)
    path = Path.join(System.tmp_dir!(), "export_#{System.unique_integer([:positive])}.bean")
    on_exit(fn -> File.rm(path) end)

    assert :ok = Storage.export_file(path)
    assert File.read!(path) == Beancount.render(ledger)
  end
end

defmodule Beancount.QueriesDocTest do
  @moduledoc """
  Guards `Beancount.Queries` moduledoc examples.
  """
  use ExUnit.Case, async: false

  alias Beancount.{Queries, Storage}

  setup do
    Storage.clear()
    on_exit(fn -> Storage.clear() end)

    assert {:ok, _} = Storage.store(Beancount.TestFixtures.queries_ledger())
    :ok
  end

  test "moduledoc filter and aggregate example" do
    opens = Queries.list_opens(prefix: "Assets")
    assert length(opens) == 2
    assert Enum.all?(opens, &String.starts_with?(&1.account, "Assets:"))

    counts = Queries.count_transactions_by_date()
    assert {~D[2026-01-15], 1} in counts
    assert {~D[2026-02-15], 1} in counts

    txns =
      Queries.find_transactions(
        payee: "Employer",
        from_date: ~D[2026-01-01],
        to_date: ~D[2026-01-31]
      )

    assert length(txns) == 1

    types = Queries.count_by_type()
    assert Keyword.get(types, :opens) == 3
    assert Keyword.get(types, :transactions) == 2
  end

  test "count_by_type/0 includes undated directive tables" do
    assert {:ok, _} =
             Storage.store([
               Beancount.option("title", "Test"),
               Beancount.include("other.bean"),
               Beancount.plugin("beancount.plugins.documents"),
               Beancount.push_tag("trip"),
               Beancount.pop_tag("trip"),
               Beancount.query_directive(~D[2026-01-01], "q", "SELECT 1")
             ])

    types = Map.new(Queries.count_by_type())
    assert types[:options] >= 1
    assert types[:includes] >= 1
    assert types[:plugins] >= 1
    assert types[:push_tags] >= 1
    assert types[:pop_tags] >= 1
    assert types[:queries] >= 1
  end
end

defmodule Beancount.RepoDocTest do
  @moduledoc """
  Guards `Beancount.Repo` is started and migrated.
  """
  use ExUnit.Case, async: false

  test "repo is running and can query directive tables" do
    import Ecto.Query

    assert Beancount.Repo.aggregate(from(o in Beancount.Schemas.Open), :count, :id) >= 0
  end
end
