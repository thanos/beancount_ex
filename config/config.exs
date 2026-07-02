import Config

# beancount_ex dispatches all execution through a configurable engine.
# The public `Beancount.*` API never changes when the engine is swapped.
config :beancount_ex,
  engine: Beancount.Engine.CLI,
  bean_check_path: "bean-check",
  bean_query_path: "bean-query",
  ecto_repos: [Beancount.Repo]

# Default storage: SQLite in-memory (zero config, in-process).
# For file persistence: config :beancount_ex, Beancount.Repo, database: "path/to/ledger.db"
config :beancount_ex, Beancount.Repo,
  database: ":memory:",
  pool_size: 1

if File.exists?(Path.join(__DIR__, "#{config_env()}.exs")) do
  import_config "#{config_env()}.exs"
end
