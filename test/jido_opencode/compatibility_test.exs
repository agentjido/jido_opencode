defmodule Jido.OpenCode.CompatibilityTest do
  use ExUnit.Case, async: false

  alias Jido.OpenCode.Compatibility
  alias Jido.OpenCode.Test.{StubCLI, StubCommand}

  setup do
    old_cli_module = Application.get_env(:jido_opencode, :cli_module)
    old_command_module = Application.get_env(:jido_opencode, :command_module)
    old_stub_cli_resolve = Application.get_env(:jido_opencode, :stub_cli_resolve)
    old_stub_command_run = Application.get_env(:jido_opencode, :stub_command_run)

    Application.put_env(:jido_opencode, :cli_module, StubCLI)
    Application.put_env(:jido_opencode, :command_module, StubCommand)
    Application.put_env(:jido_opencode, :stub_cli_resolve, fn _opts -> {:ok, %{program: "/tmp/opencode"}} end)

    Application.put_env(:jido_opencode, :stub_command_run, fn
      _program, ["--help"], _opts -> {:ok, "OpenCode CLI\nrun\n"}
      _program, ["run", "--help"], _opts -> {:ok, "Usage: opencode run --format json"}
      _program, ["--version"], _opts -> {:ok, "1.2.3"}
      _program, _args, _opts -> {:ok, "ok"}
    end)

    on_exit(fn ->
      restore_env(:jido_opencode, :cli_module, old_cli_module)
      restore_env(:jido_opencode, :command_module, old_command_module)
      restore_env(:jido_opencode, :stub_cli_resolve, old_stub_cli_resolve)
      restore_env(:jido_opencode, :stub_command_run, old_stub_command_run)
    end)

    :ok
  end

  test "status/1 returns compatibility metadata" do
    assert {:ok, metadata} = Compatibility.status([])
    assert metadata.program == "/tmp/opencode"
    assert metadata.version == "1.2.3"
  end

  test "check/1 returns :ok when compatible" do
    assert :ok = Compatibility.check([])
    assert Compatibility.compatible?([])
  end

  test "status/1 returns config error when run help tokens are missing" do
    Application.put_env(:jido_opencode, :stub_command_run, fn
      _program, ["--help"], _opts -> {:ok, "OpenCode CLI\nrun\n"}
      _program, ["run", "--help"], _opts -> {:ok, "Usage: opencode run"}
      _program, ["--version"], _opts -> {:ok, "1.2.3"}
      _program, _args, _opts -> {:ok, "ok"}
    end)

    assert {:error, %Jido.OpenCode.Error.ConfigError{key: :opencode_run_help}} = Compatibility.status([])
  end

  test "check/1 returns config error when cli resolve fails" do
    Application.put_env(:jido_opencode, :stub_cli_resolve, fn _opts -> {:error, :enoent} end)
    assert {:error, %Jido.OpenCode.Error.ConfigError{key: :opencode_cli_not_found}} = Compatibility.check([])
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
