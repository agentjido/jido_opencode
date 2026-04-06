defmodule Jido.OpenCode.Adapter do
  @moduledoc """
  `Jido.Harness.Adapter` implementation for OpenCode HTTP API.

  Communicates with the OpenCode server on port 4096 for streaming completions.
  Supports multi-provider configuration (OpenAI, Anthropic, Z.AI, Gemini, etc.).
  """

  @behaviour Jido.Harness.Adapter

  alias Jido.Harness.{Capabilities, Event, RunRequest, RuntimeContract}
  alias Jido.OpenCode.{Client, Error, EventTranslator}

  @impl true
  @spec id() :: atom()
  def id, do: :opencode

  @impl true
  @spec capabilities() :: map()
  def capabilities do
    %Capabilities{
      streaming?: true,
      tool_calls?: true,
      tool_results?: true,
      thinking?: false,
      cancellation?: true,
      multiple_models?: true,
      usage_tracking?: true
    }
  end

  @impl true
  @spec run(RunRequest.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def run(%RunRequest{} = request, opts \\ []) when is_list(opts) do
    with :ok <- check_server(opts),
         {:ok, stream} <- Client.stream_completion(request, opts) do
      stream =
        Stream.transform(stream, nil, fn event, _acc ->
          {[event], nil}
        end)
        |> Stream.concat(ensure_session_completed(request))

      {:ok, stream}
    else
      {:error, _} = error -> error
    end
  rescue
    e in [ArgumentError] ->
      {:error,
       Error.validation_error("Invalid OpenCode run request", %{details: Exception.message(e)})}
  end

  @impl true
  @spec runtime_contract() :: RuntimeContract.t()
  def runtime_contract do
    RuntimeContract.new!(%{
      provider: :opencode,
      host_env_required_any: [
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "ZAI_API_KEY",
        "GEMINI_API_KEY"
      ],
      host_env_required_all: [],
      sprite_env_forward: [
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "ZAI_API_KEY",
        "GEMINI_API_KEY",
        "ZAI_BASE_URL",
        "OPENCODE_MODEL",
        "GH_TOKEN",
        "GITHUB_TOKEN"
      ],
      sprite_env_injected: %{
        "GH_PROMPT_DISABLED" => "1",
        "GIT_TERMINAL_PROMPT" => "0"
      },
      runtime_tools_required: [],
      compatibility_probes: [
        %{
          "name" => "opencode_server",
          "command" => "curl -s http://localhost:4096/health",
          "expect_all" => ["ok"]
        }
      ],
      install_steps: [
        %{
          "tool" => "opencode-server",
          "when_missing" => true,
          "command" =>
            "if command -v npm >/dev/null 2>&1; then npm install -g opencode-ai; else echo 'npm not available'; exit 1; fi"
        }
      ],
      auth_bootstrap_steps: [],
      triage_command_template:
        "curl -s -X POST http://localhost:4096/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"{{model}}\",\"messages\":[{\"role\":\"user\",\"content\":\"$(cat {{prompt_file}})\"}]}'",
      coding_command_template:
        "curl -s -X POST http://localhost:4096/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"{{model}}\",\"messages\":[{\"role\":\"user\",\"content\":\"$(cat {{prompt_file}})\"}]}'",
      success_markers: [
        %{"type" => "result", "subtype" => "success"},
        %{"status" => "success"}
      ]
    })
  end

  @doc """
  Cancel an active streaming session.
  """
  @spec cancel_session(String.t()) :: :ok | {:error, term()}
  def cancel_session(session_id) when is_binary(session_id) do
    Client.cancel_session(session_id)
  end

  @doc """
  Check if the OpenCode server is running.
  """
  @spec server_running?(keyword()) :: boolean()
  def server_running?(opts \\ []) do
    Client.server_running?(opts)
  end

  defp check_server(opts) do
    if Client.server_running?(opts) do
      :ok
    else
      {:error,
       Error.config_error("OpenCode server is not running", %{
         key: :opencode_server_unavailable,
         details: "Ensure opencode server is running on port 4096"
       })}
    end
  end

  defp ensure_session_completed(request) do
    session_id = Uniq.UUID.uuid7()

    [
      Event.new!(%{
        type: :session_completed,
        provider: :opencode,
        session_id: session_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        payload: %{
          "cwd" => request.cwd,
          "status" => "success"
        },
        raw: nil
      })
    ]
  end
end
