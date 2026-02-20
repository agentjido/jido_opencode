defmodule Jido.OpenCode.OptionsTest do
  use ExUnit.Case, async: true

  alias Jido.Harness.RunRequest
  alias Jido.OpenCode.Options

  test "new/1 applies defaults" do
    assert {:ok, options} = Options.new(%{})
    assert options.model == "zai_custom/glm-4.5-air"
    assert options.format == "json"
    assert options.timeout_ms == 180_000
  end

  test "from_run_request/2 merges request, metadata and runtime opts" do
    request =
      RunRequest.new!(%{
        prompt: "hi",
        cwd: "/repo",
        model: "request-model",
        timeout_ms: 1_000,
        metadata: %{"opencode" => %{"model" => "meta-model", "env" => %{"A" => 1}}}
      })

    assert {:ok, options} =
             Options.from_run_request(request, model: "runtime-model", cli_path: "/tmp/opencode", env: %{"B" => "2"})

    assert options.cwd == "/repo"
    assert options.model == "runtime-model"
    assert options.timeout_ms == 1_000
    assert options.opencode_path == "/tmp/opencode"
    assert options.env == %{"B" => "2"}
  end
end
