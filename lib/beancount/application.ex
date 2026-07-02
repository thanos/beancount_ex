defmodule Beancount.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Beancount.Repo
    ]

    result = Supervisor.start_link(children, strategy: :one_for_one, name: Beancount.Supervisor)

    # Auto-migrate on startup (SQLite :memory: needs this every time)
    migrate!()

    result
  end

  defp migrate! do
    Ecto.Migrator.run(Beancount.Repo, :up, all: true)
  rescue
    _ -> :ok
  end
end
