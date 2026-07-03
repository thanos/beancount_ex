defmodule Beancount.StorageTest do
  use ExUnit.Case, async: false

  alias Beancount.Storage

  setup do
    Storage.clear()
    on_exit(fn -> Storage.clear() end)
    :ok
  end

  @ledger Beancount.TestFixtures.salary_ledger_with_equity()

  test "store/1 and load/0 round-trip directives" do
    assert {:ok, 4} = Storage.store(@ledger)

    loaded = Storage.load()
    assert length(loaded) == 4

    opens = Enum.filter(loaded, &match?(%Beancount.Directives.Open{}, &1))
    assert length(opens) == 3

    txns = Enum.filter(loaded, &match?(%Beancount.Directives.Transaction{}, &1))
    assert length(txns) == 1
    txn = hd(txns)
    assert txn.narration == "Salary"
    assert length(txn.postings) == 2
  end

  test "store/1 with transaction preserves postings and cost specs" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
        Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
          cost: %Beancount.CostSpec{per_amount: Decimal.new("150"), per_currency: "USD"}
        ),
        Beancount.posting("Assets:Cash", Decimal.new("-1500"), "USD")
      ])
    ]

    assert {:ok, 3} = Storage.store(ledger)

    loaded = Storage.load()
    txn = Enum.find(loaded, &match?(%Beancount.Directives.Transaction{}, &1))
    [stock_posting, cash_posting] = txn.postings

    assert stock_posting.account == "Assets:Stocks"
    assert Decimal.equal?(stock_posting.amount, Decimal.new("10"))
    assert stock_posting.cost.per_currency == "USD"
    assert Decimal.equal?(stock_posting.cost.per_amount, Decimal.new("150"))

    assert cash_posting.account == "Assets:Cash"
    assert Decimal.equal?(cash_posting.amount, Decimal.new("-1500"))
  end

  test "clear/0 removes all directives" do
    Storage.store(@ledger)
    assert length(Storage.load()) == 4

    Storage.clear()
    assert Storage.load() == []
  end

  test "import_file/1 and export_file/1 round-trip" do
    path = Path.join(System.tmp_dir!(), "storage_test_#{System.unique_integer([:positive])}.bean")
    File.write!(path, Beancount.render(@ledger))
    on_exit(fn -> File.rm(path) end)

    assert {:ok, 4} = Storage.import_file(path)

    export_path =
      Path.join(System.tmp_dir!(), "storage_export_#{System.unique_integer([:positive])}.bean")

    on_exit(fn -> File.rm(export_path) end)

    assert :ok = Storage.export_file(export_path)

    original = File.read!(path)
    exported = File.read!(export_path)
    assert original == exported
  end

  test "store/1 and load/0 round-trip every directive type" do
    directives = [
      Beancount.option("title", "Demo"),
      Beancount.plugin("beancount.plugins.auto", "config"),
      Beancount.include("other.bean"),
      Beancount.push_tag("trip"),
      Beancount.pop_tag("trip"),
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.commodity(~D[2026-01-01], "USD"),
      Beancount.close(~D[2026-12-31], "Assets:Bank"),
      Beancount.balance(~D[2026-06-01], "Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.price(~D[2026-01-02], "AAPL", Decimal.new("150"), "USD"),
      Beancount.note(~D[2026-01-03], "Assets:Bank", "a note"),
      Beancount.document(~D[2026-01-04], "Assets:Bank", "/tmp/receipt.pdf"),
      Beancount.event(~D[2026-01-05], "location", "Athens"),
      Beancount.custom(~D[2026-01-06], "budget", ["groceries", Decimal.new("500")]),
      Beancount.pad(~D[2026-01-07], "Assets:Bank", "Equity:Opening"),
      Beancount.query_directive(~D[2026-01-08], "recent", "SELECT date, account"),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ])
    ]

    assert {:ok, count} = Storage.store(directives)
    assert count == length(directives)

    loaded = Storage.load()

    for module <- [
          Beancount.Directives.Option,
          Beancount.Directives.Plugin,
          Beancount.Directives.Include,
          Beancount.Directives.PushTag,
          Beancount.Directives.PopTag,
          Beancount.Directives.Open,
          Beancount.Directives.Commodity,
          Beancount.Directives.Close,
          Beancount.Directives.Balance,
          Beancount.Directives.Price,
          Beancount.Directives.Note,
          Beancount.Directives.Document,
          Beancount.Directives.Event,
          Beancount.Directives.Custom,
          Beancount.Directives.Pad,
          Beancount.Directives.Query,
          Beancount.Directives.Transaction
        ] do
      assert Enum.any?(loaded, &(&1.__struct__ == module)),
             "expected a #{inspect(module)} directive to round-trip"
    end

    note = Enum.find(loaded, &match?(%Beancount.Directives.Note{}, &1))
    assert note.comment == "a note"

    event = Enum.find(loaded, &match?(%Beancount.Directives.Event{}, &1))
    assert event.type == "location"
    assert event.description == "Athens"

    price = Enum.find(loaded, &match?(%Beancount.Directives.Price{}, &1))
    assert Decimal.equal?(price.amount, Decimal.new("150"))
  end

  test "store/1 round-trips the full range of custom value types with fidelity" do
    custom =
      Beancount.custom(~D[2026-01-06], "mixed", [
        Decimal.new("1.5"),
        ~D[2026-02-02],
        %Beancount.Value.Account{name: "Assets:Bank"},
        %Beancount.Value.Tag{name: "trip"},
        %Beancount.Value.Amount{number: Decimal.new("5"), currency: "USD"}
      ])

    assert {:ok, 1} = Storage.store([custom])

    [loaded] = Storage.load()

    assert %Beancount.Directives.Custom{values: values} = loaded
    assert [decimal, date, account, tag, amount] = values
    assert Decimal.equal?(decimal, Decimal.new("1.5"))
    assert date == ~D[2026-02-02]
    assert account == %Beancount.Value.Account{name: "Assets:Bank"}
    assert tag == %Beancount.Value.Tag{name: "trip"}
    assert %Beancount.Value.Amount{number: amount_number, currency: "USD"} = amount
    assert Decimal.equal?(amount_number, Decimal.new("5"))

    # The reconstructed directive renders byte-identically to the original.
    assert Beancount.render([loaded]) == Beancount.render([custom])
  end

  test "store/1 skips entries that are not recognized directives and counts only stored ones" do
    assert {:ok, 1} =
             Storage.store([
               Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
               :not_a_directive
             ])

    loaded = Storage.load()
    assert length(loaded) == 1
    assert match?(%Beancount.Directives.Open{}, hd(loaded))
  end

  test "load/0 returns directives in date order" do
    ledger = [
      Beancount.open(~D[2026-01-02], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"])
    ]

    Storage.store(ledger)

    loaded = Storage.load()
    [first, second] = Enum.filter(loaded, &match?(%Beancount.Directives.Open{}, &1))
    assert first.date == ~D[2026-01-01]
    assert second.date == ~D[2026-01-02]
  end

  test "store/1 with an empty list stores nothing" do
    assert {:ok, 0} = Storage.store([])
    assert Storage.load() == []
  end

  test "import_file/1 returns an error for a nonexistent file" do
    assert {:error, :enoent} = Storage.import_file("/no/such/ledger.bean")
  end

  test "import_file/1 returns a structured error for an unparseable file" do
    path = Path.join(System.tmp_dir!(), "bad_#{System.unique_integer([:positive])}.bean")
    File.write!(path, "2026-02-30 open Assets:Bank USD\n")
    on_exit(fn -> File.rm(path) end)

    assert {:error, %Beancount.Parser.Error{}} = Storage.import_file(path)
  end

  describe "round-trip render fidelity" do
    test "posting price annotations (@ and @@) survive store -> load -> render" do
      ledger = [
        Beancount.transaction(~D[2026-01-02], "*", nil, "FX", [
          Beancount.posting("Assets:EUR", Decimal.new("100"), "EUR",
            price: %{amount: Decimal.new("1.1"), currency: "USD", type: :unit}
          ),
          Beancount.posting("Assets:USD", Decimal.new("-110"), "USD")
        ]),
        Beancount.transaction(~D[2026-01-03], "*", nil, "FX2", [
          Beancount.posting("Assets:EUR", Decimal.new("100"), "EUR",
            price: %{amount: Decimal.new("110"), currency: "USD", type: :total}
          ),
          Beancount.posting("Assets:USD", Decimal.new("-110"), "USD")
        ])
      ]

      assert_round_trip_render(ledger)
    end

    test "boolean/Decimal/Date option values survive store -> load -> render" do
      ledger = [
        Beancount.option("infer_tolerance_from_cost", true),
        Beancount.option("operating_currency", "USD")
      ]

      assert_round_trip_render(ledger)
    end

    test "Decimal and Date metadata values survive store -> load -> render" do
      open = %{
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])
        | metadata: %{"rate" => Decimal.new("0.05"), "since" => ~D[2026-01-01]}
      }

      assert_round_trip_render([open])
    end

    test "plugin and query directives round-trip through storage" do
      ledger = [
        Beancount.plugin("beancount.plugins.documents", "Documents"),
        Beancount.query_directive(~D[2026-01-01], "balances", "SELECT account")
      ]

      assert_round_trip_render(ledger)
    end

    test "custom term values survive store -> load with inspect round-trip" do
      custom = Beancount.custom(~D[2026-01-06], "debug", [:unexpected])
      {:ok, _} = Storage.store([custom])
      [loaded] = Storage.load()
      assert loaded.values == [":unexpected"]
    end

    test "pushtag/poptag interleaving order is preserved by load/0" do
      ledger = [
        Beancount.push_tag("a"),
        Beancount.pop_tag("a"),
        Beancount.push_tag("b"),
        Beancount.pop_tag("b")
      ]

      assert {:ok, 4} = Storage.store(ledger)

      loaded_tags =
        Storage.load()
        |> Enum.map(fn
          %Beancount.Directives.PushTag{tag: t} -> {:push, t}
          %Beancount.Directives.PopTag{tag: t} -> {:pop, t}
        end)

      assert loaded_tags == [{:push, "a"}, {:pop, "a"}, {:push, "b"}, {:pop, "b"}]
    end
  end

  defp assert_round_trip_render(ledger) do
    {:ok, _} = Storage.store(ledger)
    loaded = Storage.load()
    assert Beancount.render(loaded) == Beancount.render(ledger)
  end
end
