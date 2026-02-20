defmodule Mix.Tasks.Opencode.Compat do
  @moduledoc """
  Validate whether the local OpenCode CLI supports JSON run mode.

      mix opencode.compat
      mix opencode.compat --path /custom/opencode
  """

  @shortdoc "Validate OpenCode CLI compatibility"

  use Mix.Task

  alias Jido.OpenCode.MixTaskHelpers

  @switches [path: :string]

  @impl true
  def run(args) do
    {opts, _positional, invalid} = OptionParser.parse(args, strict: @switches)
    MixTaskHelpers.validate_options!(invalid)

    compat_opts =
      if is_binary(opts[:path]) and opts[:path] != "" do
        [opencode_path: opts[:path]]
      else
        []
      end

    case compatibility_module().status(compat_opts) do
      {:ok, metadata} ->
        Mix.shell().info([
          :green,
          "OpenCode compatibility check passed.",
          :reset,
          "\n",
          "CLI: ",
          metadata.program,
          "\n",
          "Version: ",
          metadata.version
        ])

      {:error, error} ->
        Mix.raise("""
        OpenCode compatibility check failed.

        #{Exception.message(error)}
        """)
    end
  end

  defp compatibility_module do
    Application.get_env(:jido_opencode, :compatibility_module, Jido.OpenCode.Compatibility)
  end
end
