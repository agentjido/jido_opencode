defmodule Jido.OpenCode.SystemCommandTest do
  use ExUnit.Case, async: true

  alias Jido.OpenCode.SystemCommand

  test "run/3 captures standard output" do
    assert {:ok, output} = SystemCommand.run("sh", ["-lc", "printf READY"], timeout: 5_000)
    assert output == "READY"
  end

  test "run/3 can wrap commands in a PTY when script is available" do
    case System.find_executable("script") do
      nil ->
        assert {:ok, output} = SystemCommand.run("sh", ["-lc", "printf READY"], timeout: 5_000, pty: true)
        assert output == "READY"

      _script ->
        assert {:ok, output} = SystemCommand.run("sh", ["-lc", "printf READY"], timeout: 5_000, pty: true)
        assert String.contains?(output, "READY")
    end
  end

  test "run/3 returns a timeout error when the command exceeds the deadline" do
    assert {:error, %{status: :timeout}} =
             SystemCommand.run("sh", ["-lc", "sleep 2"], timeout: 100)
  end
end
