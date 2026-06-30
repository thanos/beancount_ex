defmodule Beancount.Result do
  @moduledoc """
  Normalized result of running a Beancount check.

  A `Result` is engine-agnostic: the CLI engine and any future native engine
  populate the same struct so callers never need to special-case the backend.

  Fields:

    * `:status` - `:ok` when the ledger is valid, `:error` otherwise.
    * `:exit_status` - the raw process exit status (`nil` for non-process engines).
    * `:stdout` - captured standard output (CLI engines merge stderr here).
    * `:stderr` - unused; kept for struct symmetry. CLI output is merged into
      `:stdout` via `stderr_to_stdout: true`.
    * `:normalized` - engine-independent, structured view of the output
      produced by `Beancount.Normalizer`.
  """

  @derive {Jason.Encoder, only: [:status, :exit_status, :stdout, :stderr, :normalized]}
  defstruct status: nil, exit_status: nil, stdout: "", stderr: "", normalized: %{}

  @type status :: :ok | :error

  @type t :: %__MODULE__{
          status: status() | nil,
          exit_status: non_neg_integer() | nil,
          stdout: binary(),
          stderr: binary(),
          normalized: map()
        }
end
