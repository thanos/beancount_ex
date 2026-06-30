defmodule Beancount.Directives.Plugin do
  @moduledoc """
  The `plugin` directive loads a Beancount plugin module.

      plugin "beancount.plugins.auto_accounts" "Assets:Cash"

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
