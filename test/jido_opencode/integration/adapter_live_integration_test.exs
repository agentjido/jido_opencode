defmodule Jido.OpenCode.Integration.AdapterLiveIntegrationTest do
  use ExUnit.Case, async: false
  use Jido.OpenCode.LiveIntegrationCase

  alias Jido.Harness.RunRequest
  alias Jido.OpenCode.Adapter

  @integration_skip_reason Jido.OpenCode.LiveIntegrationCase.skip_reason()

  if @integration_skip_reason do
    @moduletag skip: @integration_skip_reason
  end

  test "adapter emits a terminal harness event via the real OpenCode CLI", ctx do
    attrs =
      %{
        prompt: ctx.prompt,
        cwd: ctx.cwd,
        timeout_ms: ctx.timeout_ms,
        metadata: %{}
      }
      |> maybe_put(:model, ctx.model)

    request = RunRequest.new!(attrs)

    assert {:ok, stream} = Adapter.run(request, ctx.cli_opts)
    events = Enum.to_list(stream)

    assert events != []
    assert Enum.all?(events, &(&1.provider == :opencode))
    assert Enum.any?(events, &(&1.type == :session_started))

    terminal =
      Enum.find(events, fn event ->
        event.type in [:session_completed, :session_failed]
      end)

    assert terminal

    if ctx.require_success? do
      assert terminal.type == :session_completed
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
