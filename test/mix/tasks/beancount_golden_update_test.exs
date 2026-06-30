defmodule Mix.Tasks.Beancount.Golden.UpdateTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Beancount.Golden
  alias Mix.Tasks.Beancount.Golden.Update

  setup do
    original = Application.get_env(:beancount_ex, :bean_check_path)
    on_exit(fn -> Application.put_env(:beancount_ex, :bean_check_path, original) end)
    :ok
  end

  test "regenerates expected.bean deterministically and skips results without bean-check" do
    Application.put_env(:beancount_ex, :bean_check_path, "definitely-not-a-real-binary-xyz")

    before = Enum.map(Golden.cases(), &Golden.expected_bean/1)

    output = capture_io(fn -> Update.run([]) end)

    assert output =~ "updated"
    assert output =~ "skipped"

    after_run = Enum.map(Golden.cases(), &Golden.expected_bean/1)
    assert before == after_run
  end

  test "regenerates expected.result.json when bean-check is available" do
    # Snapshot existing result files so we can restore the repo afterwards.
    snapshot = Map.new(Golden.cases(), fn dir -> {dir, File.read(Golden.result_path(dir))} end)

    on_exit(fn ->
      Enum.each(snapshot, fn
        {dir, {:ok, contents}} -> File.write!(Golden.result_path(dir), contents)
        {dir, {:error, _}} -> File.rm(Golden.result_path(dir))
      end)
    end)

    Beancount.FakeBeanCheck.install!()

    output = capture_io(fn -> Update.run([]) end)

    assert output =~ "expected.result.json"

    for dir <- Golden.cases() do
      assert Golden.expected_result(dir) == %{"status" => "ok", "errors" => []}
    end
  end
end
