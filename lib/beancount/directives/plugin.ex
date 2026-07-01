defmodule Beancount.Directives.Plugin do
  @moduledoc """
  The `plugin` directive loads a Beancount plugin module.

  See [Plugins](https://beancount.github.io/docs/beancount_language_syntax/#plugins).

  ## Beancount syntax

      plugin "beancount.plugins.auto_accounts"
      plugin "beancount.plugins.auto_accounts" "Assets:Cash"

  General form: `plugin "Module" ["Config"]`

  ## Elixir struct

      %Beancount.Directives.Plugin{
        module: "beancount.plugins.auto_accounts",
        config: nil
      }

      %Beancount.Directives.Plugin{
        module: "beancount.plugins.auto_accounts",
        config: "Assets:Cash"
      }

  Or use `Beancount.plugin/2`:

      Beancount.plugin("beancount.plugins.auto_accounts")
      Beancount.plugin("beancount.plugins.auto_accounts", "Assets:Cash")

  ## Fields

    * `module` - Python plugin module path as a string (Beancount plugin name).
    * `config` - optional configuration string passed to the plugin. `nil` omits
      the second argument in rendered `.bean` text.
  """

  alias Beancount.Renderer

  @enforce_keys [:module, :config]
  defstruct module: nil, config: nil

  @type t :: %__MODULE__{module: String.t(), config: String.t() | nil}

  defimpl Beancount.Directive do
    def to_bean(%{module: module, config: config}) do
      case config do
        nil ->
          "plugin " <> Renderer.quote_string(module)

        config ->
          "plugin " <> Renderer.quote_string(module) <> " " <> Renderer.quote_string(config)
      end
    end
  end
end
