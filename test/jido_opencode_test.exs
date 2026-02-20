defmodule Jido.OpenCodeTest do
  use ExUnit.Case, async: false

  alias Jido.Harness.Event
  alias Jido.Harness.RunRequest
  alias Jido.OpenCode.Test.StubAdapter

  setup do
    old_adapter_module = Application.get_env(:jido_opencode, :adapter_module)
    old_adapter_run = Application.get_env(:jido_opencode, :stub_adapter_run)

    Application.put_env(:jido_opencode, :adapter_module, StubAdapter)

    Application.put_env(:jido_opencode, :stub_adapter_run, fn request, opts ->
      send(self(), {:adapter_run, request, opts})

      {:ok,
       [
         Event.new!(%{
           type: :session_completed,
           provider: :opencode,
           session_id: "op-1",
           timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
           payload: %{"status" => "success"},
           raw: nil
         })
       ]}
    end)

    on_exit(fn ->
      restore_env(:jido_opencode, :adapter_module, old_adapter_module)
      restore_env(:jido_opencode, :stub_adapter_run, old_adapter_run)
    end)

    :ok
  end

  test "version/0 returns semver" do
    assert Jido.OpenCode.version() =~ ~r/^\d+\.\d+\.\d+$/
  end

  test "run/2 builds run request and delegates to adapter" do
    assert {:ok, stream} = Jido.OpenCode.run("hello", cwd: "/repo", model: "m1", timeout_ms: 1000)
    events = Enum.to_list(stream)

    assert_receive {:adapter_run, %RunRequest{} = request, opts}
    assert request.prompt == "hello"
    assert request.cwd == "/repo"
    assert request.model == "m1"
    assert request.timeout_ms == 1000
    assert opts[:cwd] == "/repo"
    assert Enum.map(events, & &1.type) == [:session_completed]
  end

  test "query/1 delegates to run/2 with real semantics" do
    assert {:ok, stream} = Jido.OpenCode.query("analyze this repo")
    assert [%Event{type: :session_completed}] = Enum.to_list(stream)
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
