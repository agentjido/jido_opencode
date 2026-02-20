defmodule Jido.OpenCode.AdapterTest do
  use ExUnit.Case, async: false

  use Jido.Harness.AdapterContract,
    adapter: Jido.OpenCode.Adapter,
    provider: :opencode,
    check_run: true,
    run_request: %{prompt: "ship it", cwd: "/repo", metadata: %{}}

  alias Jido.Harness.RunRequest
  alias Jido.OpenCode.Adapter
  alias Jido.OpenCode.Error
  alias Jido.OpenCode.Test.{StubCLI, StubCompatibility, StubMapper}

  setup do
    old_harness_providers = Application.get_env(:jido_harness, :providers)
    old_harness_candidates = Application.get_env(:jido_harness, :provider_candidates)
    old_compatibility_module = Application.get_env(:jido_opencode, :compatibility_module)
    old_options_module = Application.get_env(:jido_opencode, :options_module)
    old_cli_module = Application.get_env(:jido_opencode, :cli_module)
    old_mapper_module = Application.get_env(:jido_opencode, :mapper_module)
    old_compat_check = Application.get_env(:jido_opencode, :stub_compat_check)
    old_cli_run = Application.get_env(:jido_opencode, :stub_cli_run)
    old_mapper_map_event = Application.get_env(:jido_opencode, :stub_mapper_map_event)

    Application.put_env(:jido_opencode, :compatibility_module, StubCompatibility)
    Application.put_env(:jido_opencode, :cli_module, StubCLI)
    Application.put_env(:jido_opencode, :mapper_module, StubMapper)
    Application.put_env(:jido_opencode, :stub_compat_check, fn _opts -> :ok end)

    Application.put_env(:jido_opencode, :stub_cli_run, fn prompt, _options ->
      send(self(), {:opencode_run, prompt})

      {:ok,
       """
       {"type":"session_started","session_id":"oc-1","cwd":"/repo"}
       {"type":"assistant","session_id":"oc-1","text":"Working"}
       {"type":"result","session_id":"oc-1","status":"success","result":"Done"}
       """}
    end)

    on_exit(fn ->
      restore_env(:jido_opencode, :compatibility_module, old_compatibility_module)
      restore_env(:jido_opencode, :options_module, old_options_module)
      restore_env(:jido_opencode, :cli_module, old_cli_module)
      restore_env(:jido_opencode, :mapper_module, old_mapper_module)
      restore_env(:jido_opencode, :stub_compat_check, old_compat_check)
      restore_env(:jido_opencode, :stub_cli_run, old_cli_run)
      restore_env(:jido_opencode, :stub_mapper_map_event, old_mapper_map_event)
      restore_env(:jido_harness, :providers, old_harness_providers)
      restore_env(:jido_harness, :provider_candidates, old_harness_candidates)
    end)

    :ok
  end

  test "runtime_contract/0 includes opencode runtime metadata" do
    contract = Adapter.runtime_contract()
    assert contract.provider == :opencode
    assert "ZAI_API_KEY" in contract.host_env_required_any
    assert "opencode" in contract.runtime_tools_required
    assert String.contains?(contract.triage_command_template, "opencode run")
    assert String.contains?(contract.coding_command_template, "opencode run")
    assert Enum.any?(contract.auth_bootstrap_steps, &String.contains?(&1, "opencode models zai_custom"))
  end

  test "run/2 maps json output to harness events" do
    request = RunRequest.new!(%{prompt: "ship it", cwd: "/repo", metadata: %{}})
    assert {:ok, stream} = Adapter.run(request)
    events = Enum.to_list(stream)

    assert_receive {:opencode_run, "ship it"}
    assert Enum.any?(events, &(&1.type == :session_started))
    assert Enum.any?(events, &(&1.type == :output_text_delta))
    assert Enum.any?(events, &(&1.type == :session_completed))
    assert Enum.all?(events, &(&1.provider == :opencode))
  end

  test "run/2 fails on invalid json lines" do
    Application.put_env(:jido_opencode, :stub_cli_run, fn _prompt, _options ->
      {:ok, "not-json"}
    end)

    request = RunRequest.new!(%{prompt: "hello", metadata: %{}})
    assert {:error, %Error.InvalidInputError{message: "Invalid JSON output from OpenCode"}} = Adapter.run(request)
  end

  test "run/2 returns compatibility errors" do
    Application.put_env(:jido_opencode, :stub_compat_check, fn _opts ->
      {:error, Error.config_error("bad compat", %{key: :opencode_help})}
    end)

    request = RunRequest.new!(%{prompt: "hello", metadata: %{}})
    assert {:error, %Error.ConfigError{key: :opencode_help}} = Adapter.run(request)
  end

  test "run/2 emits session_failed for mapper failures" do
    Application.put_env(:jido_opencode, :stub_mapper_map_event, fn _event ->
      {:error, :mapper_failed}
    end)

    request = RunRequest.new!(%{prompt: "hello", metadata: %{}})
    assert {:ok, stream} = Adapter.run(request)
    events = Enum.to_list(stream)

    assert Enum.any?(events, &(&1.type == :session_failed))

    assert Enum.any?(events, fn event ->
             is_binary(event.payload["error"]) and String.contains?(event.payload["error"], "mapper_failed")
           end)
  end

  test "Jido.Harness.run_request/3 works with :opencode provider" do
    Application.put_env(:jido_harness, :providers, %{opencode: Adapter})
    Application.put_env(:jido_harness, :provider_candidates, %{})

    request = RunRequest.new!(%{prompt: "hello", cwd: "/repo", metadata: %{}})
    assert {:ok, stream} = Jido.Harness.run_request(:opencode, request, [])
    events = Enum.to_list(stream)

    assert Enum.any?(events, &(&1.type == :session_completed))
    assert Enum.all?(events, &(&1.provider == :opencode))
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
