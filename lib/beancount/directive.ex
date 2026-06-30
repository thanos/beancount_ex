defprotocol Beancount.Directive do
  @moduledoc """
  Protocol implemented by every Beancount directive struct.

  A directive knows how to render itself into a fragment of valid Beancount
  text via `to_bean/1`. The top-level `Beancount.Renderer` is responsible for
  joining individual directive fragments into a complete `.bean` document.

  Keeping rendering behind a protocol means new directive types can be added
  without touching the renderer, and alternative engines can introspect the
  same typed structs.
  """

  @typedoc "Any value implementing the `Beancount.Directive` protocol."
  @type t :: term()

  @doc """
  Render a single directive into Beancount text.

  The returned value is `t:iodata/0` without a trailing newline. The renderer
  takes care of separating directives.
  """
  @spec to_bean(t()) :: iodata()
  def to_bean(directive)
end
