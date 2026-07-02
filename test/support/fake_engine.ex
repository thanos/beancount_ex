defmodule Beancount.FakeEngine do
  @moduledoc false

  @behaviour Beancount.Engine

  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def ensure! do
    case start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    try do
      reset!()
    catch
      :exit, _ ->
        case start_link() do
          {:ok, _} -> :ok
          {:error, {:already_started, _}} -> :ok
        end

        reset!()
    end

    :ok
  end

  def calls, do: Agent.get(__MODULE__, & &1)

  def reset!, do: Agent.update(__MODULE__, fn _ -> [] end)

  @impl Beancount.Engine
  def render(_directives), do: ""

  @impl Beancount.Engine
  def check(_text) do
    Agent.update(__MODULE__, fn calls -> [{:check, :text} | calls] end)

    {:ok,
     %Beancount.Result{
       status: :ok,
       normalized: %{status: :ok, errors: []}
     }}
  end

  @impl Beancount.Engine
  def check_file(path) do
    Agent.update(__MODULE__, fn calls -> [{:check_file, path} | calls] end)

    {:ok,
     %Beancount.Result{
       status: :ok,
       normalized: %{status: :ok, errors: []}
     }}
  end

  @impl Beancount.Engine
  def query(_text, _bql) do
    Agent.update(__MODULE__, fn calls -> [{:query, :text} | calls] end)

    {:ok, %Beancount.Query.Result{columns: [], rows: [], raw: "", status: :ok}}
  end
end
