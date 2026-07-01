defmodule Beancount.Engine.Elixir.Index do
  @moduledoc false

  alias Beancount.Engine.Elixir.FactBase

  @ets_threshold 1_000

  @type t :: map() | nil

  @spec threshold() :: non_neg_integer()
  def threshold, do: @ets_threshold

  @spec create(FactBase.t()) :: t()
  def create(%FactBase{} = fact_base) do
    postings_by_account = :ets.new(:bql_postings_by_account, [:set, :protected])
    postings_by_date = :ets.new(:bql_postings_by_date, [:set, :protected])

    Enum.each(fact_base.postings, fn posting ->
      :ets.insert(postings_by_account, {{posting.account, posting.date}, posting})
      :ets.insert(postings_by_date, {{posting.date, posting.account}, posting})
    end)

    %{postings_by_account: postings_by_account, postings_by_date: postings_by_date}
  end

  @spec destroy(t() | nil) :: :ok
  def destroy(nil), do: :ok

  def destroy(%{postings_by_account: account_table, postings_by_date: date_table}) do
    :ets.delete(account_table)
    :ets.delete(date_table)
    :ok
  end

  @spec postings_for_account(t() | nil, FactBase.t(), String.t()) :: [map()]
  def postings_for_account(nil, %FactBase{postings: postings}, account) do
    Enum.filter(postings, &(&1.account == account))
  end

  def postings_for_account(%{postings_by_account: table}, _fact_base, account) do
    table
    |> :ets.match_object({{account, :_}, :_})
    |> Enum.map(fn {{_account, _date}, posting} -> posting end)
    |> Enum.sort_by(&{Date.to_iso8601(&1.date), &1.account})
  end
end
