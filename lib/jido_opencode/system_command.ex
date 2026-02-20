defmodule Jido.OpenCode.SystemCommand do
  @moduledoc false

  @doc false
  @spec run(String.t(), [String.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def run(program, args, opts \\ []) when is_binary(program) and is_list(args) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    env = Keyword.get(opts, :env, [])
    cd = Keyword.get(opts, :cd)

    task =
      Task.async(fn ->
        cmd_opts =
          [stderr_to_stdout: true, env: env]
          |> maybe_put(:cd, cd)

        try do
          {:ok, System.cmd(program, args, cmd_opts)}
        rescue
          error -> {:error, error}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, {output, 0}}} -> {:ok, output}
      {:ok, {:ok, {output, status}}} -> {:error, %{status: status, output: output}}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, %{status: :timeout, output: ""}}
    end
  rescue
    error -> {:error, error}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
