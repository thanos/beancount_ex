defmodule Beancount.Engine.Elixir.Reports do
  @moduledoc false

  alias Beancount.BQL
  alias Beancount.Engine.Elixir.CompiledLedger
  alias Beancount.Query.Result
  alias Beancount.Result, as: CheckResult

  @spec run([Beancount.Directive.t()], binary()) ::
          {:ok, Result.t()} | {:error, CheckResult.t()}
  def run(directives, bql) do
    case BQL.parse(bql) do
      {:ok, query} ->
        compiled = CompiledLedger.compile(directives)

        try do
          case BQL.evaluate(query, compiled) do
            {:ok, %Result{} = result} ->
              {:ok, result}

            {:error, {:unsupported_bql, _}} ->
              unsupported_bql(bql)
          end
        after
          CompiledLedger.close(compiled)
        end

      {:error, _} ->
        unsupported_bql(bql)
    end
  end

  def balances(directives),
    do:
      run(
        directives,
        "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
      )

  def balance_sheet(directives) do
    run(
      directives,
      "SELECT account, sum(position) AS balance WHERE account ~ \"^(Assets|Liabilities|Equity)\" GROUP BY account ORDER BY account"
    )
  end

  def income_statement(directives) do
    run(
      directives,
      "SELECT account, sum(position) AS balance WHERE account ~ \"^(Income|Expenses)\" GROUP BY account ORDER BY account"
    )
  end

  def holdings(directives) do
    run(
      directives,
      "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"
    )
  end

  def journal(directives, account) do
    escaped = String.replace(account, "\"", "\\\"")

    run(
      directives,
      ~s(SELECT date, flag, payee, narration, position, balance WHERE account = "#{escaped}" ORDER BY date)
    )
  end

  defp unsupported_bql(bql) do
    {:error,
     %CheckResult{
       status: :error,
       exit_status: 1,
       stdout: "unsupported native BQL: #{bql}",
       stderr: "",
       normalized: %{
         status: :error,
         errors: [%{line: nil, message: "unsupported native BQL in Engine.Elixir"}]
       }
     }}
  end
end
