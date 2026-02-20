defmodule Jido.OpenCode.Test.StubCLI do
  @moduledoc false

  def resolve(opts \\ []) do
    Application.get_env(:jido_opencode, :stub_cli_resolve, fn _opts ->
      {:ok, %{program: "/tmp/opencode"}}
    end).(opts)
  end

  def run(prompt, options) do
    Application.get_env(:jido_opencode, :stub_cli_run, fn _prompt, _options ->
      {:ok, ~s({"type":"result","status":"success","result":"ok"})}
    end).(prompt, options)
  end
end

defmodule Jido.OpenCode.Test.StubCompatibility do
  @moduledoc false

  def status(opts \\ []) do
    Application.get_env(:jido_opencode, :stub_compat_status, fn _opts ->
      {:ok,
       %{
         program: "/tmp/opencode",
         version: "1.0.0",
         required_tokens: %{
           opencode_help: ["run"],
           opencode_run_help: ["--format", "json"]
         }
       }}
    end).(opts)
  end

  def check(opts \\ []) do
    Application.get_env(:jido_opencode, :stub_compat_check, fn _opts -> :ok end).(opts)
  end
end

defmodule Jido.OpenCode.Test.StubMapper do
  @moduledoc false

  def map_event(event) do
    Application.get_env(:jido_opencode, :stub_mapper_map_event, fn value ->
      Jido.OpenCode.Mapper.map_event(value)
    end).(event)
  end
end

defmodule Jido.OpenCode.Test.StubCommand do
  @moduledoc false

  def run(program, args, opts \\ []) do
    Application.get_env(:jido_opencode, :stub_command_run, fn _program, _args, _opts ->
      {:ok, ""}
    end).(program, args, opts)
  end
end

defmodule Jido.OpenCode.Test.StubPublicOpenCode do
  @moduledoc false

  def run(prompt, opts) do
    Application.get_env(:jido_opencode, :stub_public_run, fn _prompt, _opts ->
      {:ok, [%{type: :session_started}]}
    end).(prompt, opts)
  end
end

defmodule Jido.OpenCode.Test.StubAdapter do
  @moduledoc false

  def run(request, opts) do
    Application.get_env(:jido_opencode, :stub_adapter_run, fn _request, _opts ->
      {:ok, []}
    end).(request, opts)
  end
end
