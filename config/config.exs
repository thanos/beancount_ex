import Config

# beancount_ex dispatches all execution through a configurable engine.
# The public `Beancount.*` API never changes when the engine is swapped.
config :beancount_ex,
  engine: Beancount.Engine.CLI,
  bean_check_path: "bean-check"

if File.exists?(Path.join(__DIR__, "#{config_env()}.exs")) do
  import_config "#{config_env()}.exs"
end
