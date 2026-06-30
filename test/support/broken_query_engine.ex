defmodule Beancount.BrokenQueryEngine do
  @moduledoc false

  @behaviour Beancount.Engine

  @impl Beancount.Engine
  def render(_directives), do: ""

  @impl Beancount.Engine
  def check(_text) do
    {:ok,
     %Beancount.Result{
       status: :ok,
       normalized: %{status: :ok, errors: []}
     }}
  end

  @impl Beancount.Engine
  def check_file(path), do: check(File.read!(path))

  @impl Beancount.Engine
  def query(_text, _bql) do
    {:error,
     %Beancount.Result{
       status: :error,
       normalized: %{status: :error, errors: [%{line: nil, message: "query failed"}]}
     }}
  end
end
