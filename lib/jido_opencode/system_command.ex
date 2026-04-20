defmodule Jido.OpenCode.SystemCommand do
  @moduledoc false

  @doc false
  @spec run(String.t(), [String.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def run(program, args, opts \\ []) when is_binary(program) and is_list(args) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    env = Keyword.get(opts, :env, [])
    cd = Keyword.get(opts, :cd)
    pty? = Keyword.get(opts, :pty, false)

    with {:ok, exec_program, exec_args} <- resolve_command(program, args, pty?),
         {:ok, port} <- open_port(exec_program, exec_args, env, cd) do
      read_port(port, deadline_after(timeout), [])
    end
  rescue
    error -> {:error, error}
  end

  defp resolve_command(program, args, true) do
    case pty_command(program, args) do
      {:ok, wrapped_program, wrapped_args} -> {:ok, wrapped_program, wrapped_args}
      :error -> {:ok, program, args}
    end
  end

  defp resolve_command(program, args, false), do: {:ok, program, args}

  defp open_port(program, args, env, cd) do
    port =
      Port.open({:spawn_executable, to_charlist(resolve_executable!(program))}, port_opts(args, env, cd))

    {:ok, port}
  rescue
    error -> {:error, error}
  end

  defp read_port(port, deadline_ms, output) do
    receive do
      {^port, {:data, chunk}} ->
        read_port(port, deadline_ms, [output, chunk])

      {^port, {:exit_status, 0}} ->
        {:ok, normalize_output(IO.iodata_to_binary(output))}

      {^port, {:exit_status, status}} ->
        {:error, %{status: status, output: normalize_output(IO.iodata_to_binary(output))}}
    after
      remaining_timeout(deadline_ms) ->
        Port.close(port)
        {:error, %{status: :timeout, output: normalize_output(IO.iodata_to_binary(output))}}
    end
  end

  defp deadline_after(timeout) do
    System.monotonic_time(:millisecond) + timeout
  end

  defp remaining_timeout(deadline_ms) do
    max(deadline_ms - System.monotonic_time(:millisecond), 0)
  end

  defp port_opts(args, env, cd) do
    [
      :binary,
      :exit_status,
      :hide,
      :use_stdio,
      :stderr_to_stdout,
      args: Enum.map(args, &to_charlist/1),
      env: Enum.map(env, fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
    ]
    |> maybe_put_tuple(:cd, cd && to_charlist(cd))
  end

  defp pty_command(program, args) do
    case System.find_executable("script") do
      nil ->
        :error

      script ->
        case :os.type() do
          {:unix, :darwin} ->
            {:ok, script, ["-q", "/dev/null", program | args]}

          {:unix, _} ->
            shell_command =
              ["exec", shell_escape(program) | Enum.map(args, &shell_escape/1)]
              |> Enum.join(" ")

            {:ok, script, ["-q", "-e", "-c", shell_command, "/dev/null"]}

          _ ->
            :error
        end
    end
  end

  defp normalize_output(output) do
    output
    |> String.replace_prefix("^D\b\b", "")
    |> String.replace_prefix("^\u0008\u0008", "")
  end

  defp shell_escape(value) when is_binary(value) do
    escaped = String.replace(value, "'", "'\"'\"'")
    "'#{escaped}'"
  end

  defp resolve_executable!(program) when is_binary(program) do
    cond do
      String.contains?(program, "/") and File.regular?(program) ->
        program

      resolved = System.find_executable(program) ->
        resolved

      true ->
        raise ArgumentError, "executable not found: #{program}"
    end
  end

  defp maybe_put_tuple(opts, _key, nil), do: opts
  defp maybe_put_tuple(opts, key, value), do: [{key, value} | opts]
end
