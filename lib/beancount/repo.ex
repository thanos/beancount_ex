defmodule Beancount.Repo do
  use Ecto.Repo,
    otp_app: :beancount_ex,
    adapter: Ecto.Adapters.SQLite3
end
