import Config

# Keep test output readable: suppress Ecto's per-query debug SQL and the
# migration info banners that otherwise flood every DB-touching test.
config :logger, level: :warning

config :beancount_ex, Beancount.Repo, log: false
