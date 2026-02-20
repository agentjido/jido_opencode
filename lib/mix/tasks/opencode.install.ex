defmodule Mix.Tasks.Opencode.Install do
  @moduledoc """
  Check for the OpenCode CLI and provide installation instructions.

      mix opencode.install
      mix opencode.install --path /custom/opencode
  """

  @shortdoc "Check OpenCode CLI installation and provide setup instructions"

  use Mix.Task

  alias Jido.OpenCode.CLI
  alias Jido.OpenCode.MixTaskHelpers

  @switches [path: :string]

  @impl true
  def run(args) do
    {opts, _positional, invalid} = OptionParser.parse(args, strict: @switches)
    MixTaskHelpers.validate_options!(invalid)

    resolve_opts =
      if is_binary(opts[:path]) and opts[:path] != "" do
        [opencode_path: opts[:path]]
      else
        []
      end

    case cli_module().resolve(resolve_opts) do
      {:ok, spec} ->
        Mix.shell().info(["OpenCode CLI found: ", :green, spec.program, :reset])

      {:error, _reason} ->
        Mix.shell().info([
          :yellow,
          "OpenCode CLI not found.",
          :reset,
          "\n\n",
          "Install the OpenCode CLI:\n\n",
          "  npm install -g opencode-ai\n\n",
          "Then verify installation:\n\n",
          "  mix opencode.install\n"
        ])
    end
  end

  defp cli_module do
    Application.get_env(:jido_opencode, :cli_module, CLI)
  end
end
