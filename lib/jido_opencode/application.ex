defmodule Jido.OpenCode.Application do
  @moduledoc """
  OTP Application for Jido.OpenCode.

  Starts the supervision tree including:
  - SessionRegistry for tracking active streaming sessions
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Jido.OpenCode.SessionRegistry
    ]

    opts = [strategy: :one_for_one, name: Jido.OpenCode.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
