defmodule Mix.Tasks.OpencodeTasksTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Jido.OpenCode.Test.{StubCLI, StubCompatibility, StubPublicOpenCode}
  alias Mix.Tasks.Opencode.{Compat, Install, Smoke}

  setup do
    old_cli_module = Application.get_env(:jido_opencode, :cli_module)
    old_compatibility_module = Application.get_env(:jido_opencode, :compatibility_module)
    old_public_module = Application.get_env(:jido_opencode, :public_module)
    old_stub_cli_resolve = Application.get_env(:jido_opencode, :stub_cli_resolve)
    old_stub_compat_status = Application.get_env(:jido_opencode, :stub_compat_status)
    old_stub_public_run = Application.get_env(:jido_opencode, :stub_public_run)

    Application.put_env(:jido_opencode, :cli_module, StubCLI)
    Application.put_env(:jido_opencode, :compatibility_module, StubCompatibility)
    Application.put_env(:jido_opencode, :public_module, StubPublicOpenCode)
    Application.put_env(:jido_opencode, :stub_cli_resolve, fn _opts -> {:ok, %{program: "/tmp/opencode"}} end)

    Application.put_env(:jido_opencode, :stub_compat_status, fn _opts ->
      {:ok,
       %{
         program: "/tmp/opencode",
         version: "1.2.3",
         required_tokens: %{opencode_help: ["run"], opencode_run_help: ["--format", "json"]}
       }}
    end)

    Application.put_env(:jido_opencode, :stub_public_run, fn prompt, opts ->
      send(self(), {:smoke_run, prompt, opts})
      {:ok, [%{type: :session_started}]}
    end)

    on_exit(fn ->
      restore_env(:jido_opencode, :cli_module, old_cli_module)
      restore_env(:jido_opencode, :compatibility_module, old_compatibility_module)
      restore_env(:jido_opencode, :public_module, old_public_module)
      restore_env(:jido_opencode, :stub_cli_resolve, old_stub_cli_resolve)
      restore_env(:jido_opencode, :stub_compat_status, old_stub_compat_status)
      restore_env(:jido_opencode, :stub_public_run, old_stub_public_run)
    end)

    :ok
  end

  test "mix opencode.install prints found message" do
    Mix.Task.reenable("opencode.install")

    output =
      capture_io(fn ->
        Install.run([])
      end)

    assert output =~ "OpenCode CLI found"
    assert output =~ "/tmp/opencode"
  end

  test "mix opencode.install prints instructions when missing" do
    Application.put_env(:jido_opencode, :stub_cli_resolve, fn _opts -> {:error, :enoent} end)
    Mix.Task.reenable("opencode.install")

    output =
      capture_io(fn ->
        Install.run([])
      end)

    assert output =~ "OpenCode CLI not found"
    assert output =~ "npm install -g opencode-ai"
  end

  test "mix opencode.compat prints success" do
    Mix.Task.reenable("opencode.compat")

    output =
      capture_io(fn ->
        Compat.run([])
      end)

    assert output =~ "OpenCode compatibility check passed"
    assert output =~ "/tmp/opencode"
  end

  test "mix opencode.compat raises on failure" do
    Application.put_env(:jido_opencode, :stub_compat_status, fn _opts ->
      {:error, RuntimeError.exception("bad compat")}
    end)

    Mix.Task.reenable("opencode.compat")

    assert_raise Mix.Error, ~r/OpenCode compatibility check failed/, fn ->
      capture_io(fn ->
        Compat.run([])
      end)
    end
  end

  test "mix opencode.smoke executes run with options" do
    Mix.Task.reenable("opencode.smoke")

    output =
      capture_io(fn ->
        Smoke.run(["Say hello", "--cwd", "/tmp/repo", "--timeout", "3000", "--model", "zai_custom/glm-4.5-air"])
      end)

    assert_receive {:smoke_run, "Say hello", opts}
    assert opts[:cwd] == "/tmp/repo"
    assert opts[:timeout_ms] == 3000
    assert opts[:model] == "zai_custom/glm-4.5-air"
    assert output =~ "Smoke run completed"
  end

  test "mix opencode.smoke validates missing prompt" do
    Mix.Task.reenable("opencode.smoke")

    assert_raise Mix.Error, ~r/expected exactly one PROMPT argument/, fn ->
      capture_io(fn ->
        Smoke.run([])
      end)
    end
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
