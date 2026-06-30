defmodule Beancount.QueryTest do
  use ExUnit.Case, async: false

  alias Beancount.Query
  alias Beancount.Query.Result

  doctest Beancount.Query.Result

  test "Result.to_maps/1 keys rows by column name" do
    result = %Result{columns: ["account", "balance"], rows: [["Assets:Bank", "5000 USD"]]}
    assert Result.to_maps(result) == [%{"account" => "Assets:Bank", "balance" => "5000 USD"}]
  end

  setup do
    original = Application.get_env(:beancount_ex, :bean_query_path)
    on_exit(fn -> Application.put_env(:beancount_ex, :bean_query_path, original) end)
    :ok
  end

  describe "parse_csv/1" do
    test "parses a simple table" do
      csv = "account,balance\r\nAssets:Bank,5000 USD\r\n"
      assert {["account", "balance"], [["Assets:Bank", "5000 USD"]]} = Query.parse_csv(csv)
    end

    test "handles quoted fields with embedded newlines" do
      csv = ~s(a,b\n"x\ny",z\n)
      assert {["a", "b"], [["x\ny", "z"]]} = Query.parse_csv(csv)
    end

    test "handles quoted fields with embedded commas and quotes" do
      csv = ~s(a,b\n"x,y","he said ""hi"""\n)
      assert {["a", "b"], [["x,y", ~s(he said "hi")]]} = Query.parse_csv(csv)
    end

    test "empty input yields empty columns and rows" do
      assert {[], []} = Query.parse_csv("")
      assert {[], []} = Query.parse_csv("   \n")
    end

    test "header only yields no rows" do
      assert {["a", "b"], []} = Query.parse_csv("a,b\n")
    end

    test "raises on unclosed double quote" do
      assert_raise ArgumentError, "unclosed double quote in CSV field", fn ->
        Query.parse_csv(~s("open))
      end
    end

    test "handles carriage-return line endings" do
      assert {["a", "b"], [["x", "y"]]} = Query.parse_csv("a,b\rx,y\r")
    end
  end

  describe "configuration and availability" do
    test "bean_query_path/0 reflects configuration" do
      Application.put_env(:beancount_ex, :bean_query_path, "/x/bean-query")
      assert Query.bean_query_path() == "/x/bean-query"
    end

    test "available?/0 is false for a missing executable" do
      Application.put_env(:beancount_ex, :bean_query_path, "definitely-not-real-bean-query")
      refute Query.available?()
    end

    test "query_text/2 raises NotInstalledError when unavailable" do
      Application.put_env(:beancount_ex, :bean_query_path, "definitely-not-real-bean-query")

      assert_raise Query.NotInstalledError, fn ->
        Query.query_text("2026-01-01 open Assets:Bank USD\n", "SELECT account")
      end
    end
  end

  describe "with a fake bean-query" do
    setup do
      Beancount.FakeBeanQuery.install!()
      :ok
    end

    test "query_text/2 returns a parsed Query.Result on success" do
      assert {:ok, result} = Query.query_text("ledger", "SELECT account, balance")
      assert result.columns == ["account", "balance"]
      assert ["Assets:Bank", "5000 USD"] in result.rows
      assert result.status == :ok
      assert result.raw =~ "Assets:Bank"
    end

    test "query_text/2 returns {:error, Result} on failure" do
      assert {:error, result} = Query.query_text("ledger", "SELECT FAIL")
      assert %Beancount.Result{status: :error, exit_status: 1} = result
      assert [%{message: message} | _] = result.normalized.errors
      assert message =~ "forced failure"
    end

    test "query_file/2 runs against a file on disk" do
      path = Path.join(System.tmp_dir!(), "query_file_#{System.unique_integer([:positive])}.bean")
      File.write!(path, "2026-01-01 open Assets:Bank USD\n")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, result} = Query.query_file(path, "SELECT account, balance")
      assert result.columns == ["account", "balance"]
    end
  end
end
