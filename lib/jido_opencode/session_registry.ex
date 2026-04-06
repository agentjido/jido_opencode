defmodule Jido.OpenCode.SessionRegistry do
  @moduledoc """
  ETS-based registry for tracking active OpenCode sessions.

  Provides session tracking and cancellation support for streaming
  requests. Each session is registered with a unique ID and can be
  cancelled by other processes.
  """

  use GenServer

  @table :jido_opencode_sessions

  @doc """
  Starts the SessionRegistry as part of the OTP supervision tree.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new session with the given session ID.

  The owner PID is tracked for cancellation purposes.
  """
  @spec register(String.t(), pid()) :: :ok
  def register(session_id, owner_pid) when is_binary(session_id) and is_pid(owner_pid) do
    GenServer.call(__MODULE__, {:register, session_id, owner_pid})
  end

  @doc """
  Unregisters a session when it completes or is cancelled.
  """
  @spec unregister(String.t()) :: :ok
  def unregister(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:unregister, session_id})
  end

  @doc """
  Cancels an active session by ID.

  Sends a cancellation signal to the owner process if the session exists.
  """
  @spec cancel(String.t()) :: :ok | {:error, :not_found}
  def cancel(session_id) when is_binary(session_id) do
    GenServer.call(__MODULE__, {:cancel, session_id})
  end

  @doc """
  Looks up the owner PID for a session.
  """
  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(session_id) when is_binary(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, pid}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all active session IDs.
  """
  @spec list() :: [String.t()]
  def list do
    :ets.select(@table, [{{:"$1", :_}, [], [:"$1"]}])
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :protected, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, session_id, owner_pid}, _from, %{table: table} = state) do
    :ets.insert(table, {session_id, owner_pid})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, session_id}, _from, %{table: table} = state) do
    :ets.delete(table, session_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:cancel, session_id}, _from, %{table: table} = state) do
    case :ets.lookup(table, session_id) do
      [{^session_id, pid}] ->
        send(pid, {:jido_opencode_cancel, session_id})
        :ets.delete(table, session_id)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
end
