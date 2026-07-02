# Integration tests that require a real Beancount installation are excluded by
# default so that `mix test` passes without Beancount installed.
#
#     mix test                     # unit + property + golden (no Beancount)
#     mix test --include beancount # also run integration tests
ExUnit.start(exclude: [:integration, :beancount, :explorer])
