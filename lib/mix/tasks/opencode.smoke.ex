defmodule Mix.Tasks.Opencode.Smoke do
  @moduledoc """
  Execute a minimal OpenCode prompt for smoke validation.

      mix opencode.smoke "Return OK"
      mix opencode.smoke "Summarize this repo" --cwd /path --timeout 30000 --model zai_custom/glm-4.5-air
  """

  @shortdoc "Run a minimal OpenCode smoke prompt"

  use Mix.Task

  alias Jido.OpenCode.MixTaskHelpers

  @switches [cwd: :string, timeout: :integer, model: :string]

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)
    MixTaskHelpers.validate_options!(invalid)

    prompt =
      case positional do
        [value] -> value
        _ -> Mix.raise("expected exactly one PROMPT argument")
      end

    run_opts =
      []
      |> maybe_put(:cwd, opts[:cwd])
      |> maybe_put(:timeout_ms, opts[:timeout])
      |> maybe_put(:model, opts[:model])

    Mix.shell().info(["Running OpenCode smoke prompt..."])

    case public_module().run(prompt, run_opts) do
      {:ok, stream} ->
        count = stream |> Enum.take(10_000) |> length()
        Mix.shell().info("Smoke run completed with #{count} normalized events.")

      {:error, reason} ->
        Mix.raise("OpenCode smoke run failed: #{format_error(reason)}")
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp format_error(%{message: message}) when is_binary(message), do: message
  defp format_error(reason), do: inspect(reason)

  defp public_module do
    Application.get_env(:jido_opencode, :public_module, Jido.OpenCode)
  end
end
