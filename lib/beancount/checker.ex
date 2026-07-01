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

  ## Examples

      iex> is_binary(Beancount.Checker.bean_check_path())
      true

  """
  @spec bean_check_path() :: String.t()
  def bean_check_path do
    Application.get_env(:beancount_ex, :bean_check_path, "bean-check")
  end

  @doc """
  Whether the configured `bean-check` executable is available on this machine.

  ## Examples

      iex> is_boolean(Beancount.Checker.available?())
      true

  """
  @spec available?() :: boolean()
  def available? do
    path = bean_check_path()
    File.regular?(path) or System.find_executable(path) != nil
  end

  @doc """
  Check Beancount text by writing it to a temporary file and validating it.

  ## Examples

      text = \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\"

      if Beancount.Checker.available?() do
        {:ok, %Beancount.Result{status: :ok}} = Beancount.Checker.check_text(text)
      end

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

  ## Examples

      path = Path.join(System.tmp_dir!(), "checker_example.bean")

      File.write!(path, \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\")

      if Beancount.Checker.available?() do
        {:ok, _} = Beancount.Checker.check_file(path)
      end

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
