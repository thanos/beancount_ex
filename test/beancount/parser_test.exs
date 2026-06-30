defmodule Beancount.ParserTest do
  use ExUnit.Case, async: true

  test "parse_text/1 parses a simple transaction" do
    text = """
    2026-01-01 open Assets:Bank USD

    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -5000 USD
    """

    assert {:ok, directives} = Beancount.parse_text(text)
    assert length(directives) == 2
    assert [%Beancount.Directives.Open{}, %Beancount.Directives.Transaction{}] = directives
  end

  test "parse/1 passes directive lists through" do
    directive = Beancount.commodity(~D[2026-01-01], "USD")
    assert {:ok, [^directive]} = Beancount.parse([directive])
  end

  test "parse!/1 raises on invalid input" do
    assert_raise Beancount.Parser.Error, fn ->
      Beancount.parse!("not a directive")
    end
  end

  test "parse_text/1 returns structured errors" do
    assert {:error, %Beancount.Parser.Error{message: message, line: line}} =
             Beancount.parse_text("2026-01-01 open")

    assert is_binary(message)
    assert is_integer(line)
  end

  test "parse_text/1 parses query, plugin, and tag directives" do
    text = """
    2026-01-01 query "balances" "SELECT account"
    plugin "beancount.plugins.auto_accounts"
    pushtag #trip
    poptag #trip
    """

    assert {:ok,
            [
              %Beancount.Directives.Query{name: "balances"},
              %Beancount.Directives.Plugin{},
              %Beancount.Directives.PushTag{tag: "trip"},
              %Beancount.Directives.PopTag{tag: "trip"}
            ]} = Beancount.parse_text(text)
  end

  test "public constructors build new directive types" do
    assert %Beancount.Directives.Query{} =
             Beancount.query_directive(~D[2026-01-01], "balances", "SELECT account")

    assert %Beancount.Directives.Plugin{} = Beancount.plugin("mod")
    assert %Beancount.Directives.PushTag{} = Beancount.push_tag("trip")
    assert %Beancount.Directives.PopTag{} = Beancount.pop_tag("trip")
  end
end
