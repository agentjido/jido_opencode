defmodule Jido.OpenCode.Client do
  @moduledoc """
  HTTP client for the OpenCode server API.

  Communicates with the OpenCode server on port 4096 for streaming
  completions, tool calls, and session management.
  """

  alias Jido.Harness.{Event, RunRequest}
  alias Jido.OpenCode.{Error, EventTranslator, SessionRegistry}

  @default_port 4096
  @default_host "localhost"
  @default_timeout 300_000

  @typedoc "Client options"
  @type opts() :: keyword()

  @doc """
  Sends a streaming completion request to the OpenCode server.

  ## Options

    * `:host` - Server host (default: "localhost")
    * `:port` - Server port (default: 4096)
    * `:timeout` - Request timeout in ms (default: 300000)
    * `:model` - Model to use (default: from request or env)
    * `:tools` - List of tool definitions for tool calling
    * `:provider` - Provider configuration map

  Returns a lazy stream of `Jido.Harness.Event` structs.
  """
  @spec stream_completion(RunRequest.t(), opts()) :: {:ok, Enumerable.t()} | {:error, term()}
  def stream_completion(%RunRequest{} = request, opts \\ []) do
    host = Keyword.get(opts, :host, @default_host)
    port = Keyword.get(opts, :port, @default_port)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    session_id = generate_session_id()
    :ok = SessionRegistry.register(session_id, self())

    url = "http://#{host}:#{port}/v1/chat/completions"

    body = build_request_body(request, opts)

    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "text/event-stream"}
    ]

    req_options = [
      url: url,
      headers: headers,
      body: Jason.encode!(body),
      connect_options: [timeout: 30_000],
      receive_timeout: timeout
    ]

    stream =
      Req.new(req_options)
      |> Req.post!(into: :stream)
      |> then(fn resp -> resp.body end)
      |> Stream.transform(
        fn ->
          {
            :incomplete,
            "",
            session_id,
            request.cwd,
            Keyword.get(opts, :model, default_model())
          }
        end,
        &process_sse_chunk/2,
        fn _state -> :ok end
      )
      |> Stream.take_while(fn
        %Event{type: :session_cancelled} -> false
        _ -> true
      end)

    {:ok, stream}
  rescue
    e in Mint.TransportError ->
      {:error,
       Error.config_error("Cannot connect to OpenCode server", %{
         key: :opencode_server_unavailable,
         details: Exception.message(e)
       })}

    e ->
      {:error,
       Error.execution_error("OpenCode HTTP request failed", %{
         details: Exception.message(e)
       })}
  end

  @doc """
  Cancel an active session.
  """
  @spec cancel_session(String.t()) :: :ok | {:error, term()}
  def cancel_session(session_id) when is_binary(session_id) do
    SessionRegistry.cancel(session_id)
  end

  @doc """
  Check if the OpenCode server is running.
  """
  @spec server_running?(opts()) :: boolean()
  def server_running?(opts \\ []) do
    host = Keyword.get(opts, :host, @default_host)
    port = Keyword.get(opts, :port, @default_port)

    url = "http://#{host}:#{port}/health"

    case Req.get(url, connect_options: [timeout: 5_000], receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @spec build_request_body(RunRequest.t(), opts()) :: map()
  defp build_request_body(%RunRequest{} = request, opts) do
    model = Keyword.get(opts, :model, default_model())
    tools = Keyword.get(opts, :tools, [])
    provider = Keyword.get(opts, :provider, %{provider: "openai"})

    messages = [
      %{
        role: "user",
        content: request.prompt
      }
    ]

    base = %{
      model: model,
      messages: messages,
      stream: true
    }

    base
    |> maybe_add_tools(tools)
    |> maybe_add_provider(provider)
  end

  defp maybe_add_tools(body, []), do: body

  defp maybe_add_tools(body, tools) when is_list(tools) do
    Map.put(body, :tools, tools)
  end

  defp maybe_add_provider(body, nil), do: body

  defp maybe_add_provider(body, provider) when is_map(provider) do
    Map.put(body, :provider, provider)
  end

  defp process_sse_chunk(chunk, {status, buffer, session_id, cwd, model} = state) do
    data = buffer <> chunk

    lines = String.split(data, "\n")

    {remaining, events} =
      lines
      |> Enum.reduce({"", []}, fn line, {acc, evs} ->
        line = String.trim(line)

        case line do
          "" ->
            if acc != "" do
              case parse_sse_event(acc) do
                {:ok, event} -> {"", evs ++ [event]}
                {:error, _} -> {"", evs}
              end
            else
              {"", evs}
            end

          "data:" <> rest ->
            {String.trim_leading(rest), evs}

          _ ->
            {acc <> line, evs}
        end
      end)

    translated = Enum.flat_map(events, &EventTranslator.translate(&1, session_id, cwd, model))

    if translated == [] do
      {[{:cont, state}], state}
    else
      {[{:cont, translated}], {status, remaining, session_id, cwd, model}}
    end
  end

  defp parse_sse_event(data) do
    case Jason.decode(data) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      _ ->
        if data == "[DONE]" do
          {:ok, %{"done" => true}}
        else
          {:error, :invalid_json}
        end
    end
  end

  defp generate_session_id do
    Uniq.UUID.uuid7()
  end

  defp default_model do
    System.get_env("OPENCODE_MODEL", "gpt-4")
  end
end
