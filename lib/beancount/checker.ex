defmodule Beancount.Checker do
  @moduledoc """
  Low-level wrapper around the `bean-check` command-line tool.

  `Checker` is the only place that shells out to Beancount. It is used by
  `Beancount.Engine.CLI` and is kept separate so the process-management
  concerns (locating the binary, temp files, capturing output) live in one
  place.

  The path to `bean-check` is configurable:

      config :beancount_ex, bean_check_path: "bean-check"

  """

  alias Beancount.{Normalizer, Result}

  defmodule NotInstalledError do
    @moduledoc """
    Raised when the configured `bean-check` executable cannot be located.

    This signals an environment/setup problem, distinct from a ledger that
    fails validation (which is returned as `{:error, %Beancount.Result{}}`).
    """
    defexception [:message]
  end

  @doc """
  Return the configured path to the `bean-check` executable.
  """
  @spec bean_check_path() :: String.t()
  def bean_check_path do
    Application.get_env(:beancount_ex, :bean_check_path, "bean-check")
  end

  @doc """
  Whether the configured `bean-check` executable is available on this machine.
  """
  @spec available?() :: boolean()
  def available? do
    path = bean_check_path()
    File.regular?(path) or System.find_executable(path) != nil
  end

  @doc """
  Check Beancount text by writing it to a temporary file and validating it.
  """
  @spec check_text(binary()) :: {:ok, Result.t()} | {:error, Result.t()}
  def check_text(text) when is_binary(text) do
    path = Path.join(System.tmp_dir!(), "beancount_ex_#{System.unique_integer([:positive])}.bean")
    File.write!(path, text)

    try do
      check_file(path)
    after
      File.rm(path)
    end
  end

  @doc """
  Check a `.bean` file on disk, returning a normalized `Beancount.Result`.

  Raises `Beancount.Checker.NotInstalledError` if `bean-check` is not available.
  """
  @spec check_file(Path.t()) :: {:ok, Result.t()} | {:error, Result.t()}
  def check_file(path) do
    ensure_available!()
    path = Path.expand(path)

    {output, exit_status} =
      System.cmd(bean_check_path(), [path], stderr_to_stdout: true)

    build_result(exit_status, output, "", path)
  end

  defp build_result(exit_status, stdout, stderr, source_path) do
    normalized = Normalizer.normalize(exit_status, stdout, stderr, source_path)

    result = %Result{
      status: normalized.status,
      exit_status: exit_status,
      stdout: stdout,
      stderr: stderr,
      normalized: normalized
    }

    {result.status, result}
  end

  defp ensure_available! do
    unless available?() do
      raise NotInstalledError,
        message:
          "bean-check executable not found at #{inspect(bean_check_path())}. " <>
            "Install Beancount (`pip install beancount`) or configure " <>
            ":beancount_ex, :bean_check_path."
    end
  end
end
