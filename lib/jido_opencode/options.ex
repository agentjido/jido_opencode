defmodule Jido.OpenCode.Options do
  @moduledoc """
  Normalized runtime options for OpenCode CLI execution.
  """

  alias Jido.Harness.RunRequest

  @option_keys [:cwd, :model, :timeout_ms, :format, :env, :opencode_path, :cli_path]
  @option_key_strings Enum.map(@option_keys, &Atom.to_string/1)

  @schema Zoi.struct(
            __MODULE__,
            %{
              cwd: Zoi.string() |> Zoi.nullable() |> Zoi.optional(),
              model: Zoi.string() |> Zoi.default("zai-coding-plan/glm-4.5-air"),
              timeout_ms: Zoi.integer() |> Zoi.default(180_000),
              format: Zoi.string() |> Zoi.default("json"),
              env: Zoi.map(Zoi.string(), Zoi.string()) |> Zoi.default(%{}),
              opencode_path: Zoi.string() |> Zoi.nullable() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the option schema."
  @spec schema() :: Zoi.schema()
  def schema, do: @schema

  @doc "Builds options from a map, keyword list, or options struct."
  @spec new(keyword() | map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = options), do: {:ok, options}
  def new(options) when is_list(options), do: options |> Enum.into(%{}) |> new()

  def new(options) when is_map(options) do
    options
    |> sanitize_options()
    |> then(&Zoi.parse(@schema, &1))
  end

  @doc "Like `new/1` but raises on validation errors."
  @spec new!(keyword() | map() | t()) :: t()
  def new!(options) do
    case new(options) do
      {:ok, parsed} -> parsed
      {:error, reason} -> raise ArgumentError, "Invalid Jido.OpenCode options: #{inspect(reason)}"
    end
  end

  @doc """
  Builds options from a normalized run request plus runtime opts.
  """
  @spec from_run_request(RunRequest.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def from_run_request(%RunRequest{} = request, opts \\ []) when is_list(opts) do
    metadata =
      request.metadata
      |> Map.get("opencode", Map.get(request.metadata, :opencode, %{}))
      |> normalize_map_keys()

    request_opts =
      %{
        cwd: request.cwd,
        model: request.model,
        timeout_ms: request.timeout_ms
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    runtime_opts =
      opts
      |> Keyword.take(@option_keys)
      |> Enum.into(%{})
      |> maybe_move_cli_path()

    request_opts
    |> Map.merge(metadata)
    |> Map.merge(runtime_opts)
    |> new()
  end

  defp normalize_map_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) ->
        if key in @option_keys, do: Map.put(acc, key, value), else: acc

      {key, value}, acc when is_binary(key) ->
        if key in @option_key_strings do
          Map.put(acc, String.to_existing_atom(key), value)
        else
          acc
        end

      _, acc ->
        acc
    end)
  end

  defp normalize_map_keys(_), do: %{}

  defp sanitize_options(options) when is_map(options) do
    options
    |> maybe_move_cli_path()
    |> sanitize_env()
  end

  defp maybe_move_cli_path(options) do
    cond do
      Map.has_key?(options, :opencode_path) -> options
      Map.has_key?(options, "opencode_path") -> options
      Map.has_key?(options, :cli_path) -> Map.put(options, :opencode_path, Map.get(options, :cli_path))
      Map.has_key?(options, "cli_path") -> Map.put(options, "opencode_path", Map.get(options, "cli_path"))
      true -> options
    end
  end

  defp sanitize_env(options) do
    env = map_get(options, :env, %{})

    normalized_env =
      if is_map(env) do
        env
        |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
        |> Map.new()
      else
        %{}
      end

    map_put(options, :env, normalized_env)
  end

  defp map_get(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp map_put(map, key, value) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.put(map, key, value)
      Map.has_key?(map, Atom.to_string(key)) -> Map.put(map, Atom.to_string(key), value)
      true -> Map.put(map, key, value)
    end
  end
end
