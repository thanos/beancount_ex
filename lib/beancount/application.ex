defmodule Beancount.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      Beancount.Repo
    ]

    result = Supervisor.start_link(children, strategy: :one_for_one, name: Beancount.Supervisor)

    # Auto-migrate on startup (SQLite :memory: needs this every time).
    migrate!()

    result
  end

  defp migrate! do
    Ecto.Migrator.run(Beancount.Repo, :up, all: true)
  rescue
    error ->
      # A failed migration must surface loudly: swallowing it here would turn
      # every later Storage/Queries call into a confusing "no such table" error
      # far from the root cause.
      Logger.error("Beancount.Repo migration failed: #{Exception.message(error)}")
      reraise error, __STACKTRACE__
  end
end
