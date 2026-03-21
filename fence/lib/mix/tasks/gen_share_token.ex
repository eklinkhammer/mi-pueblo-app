defmodule Mix.Tasks.Fence.GenShareToken do
  @moduledoc """
  Generates a share token for a user by email.

  ## Usage

      mix fence.gen_share_token user@email.com

  Prints a shareable URL that can be opened in a browser to access the web view.
  """
  @shortdoc "Generate a web share token for a user"

  use Mix.Task

  @dialyzer :no_match
  @impl Mix.Task
  def run([email]) do
    Mix.Task.run("app.start")

    case Fence.Accounts.get_user_by_email(email) do
      nil ->
        Mix.shell().error("No user found with email: #{email}")

      user ->
        case Fence.Accounts.create_share_token(user.id) do
          {:ok, share_token} ->
            url = "http://localhost:4000/web/map?token=#{share_token.token}"
            Mix.shell().info("Share token created for #{user.email}")
            Mix.shell().info("Expires: #{share_token.expires_at}")
            Mix.shell().info("\nOpen this URL in your browser:\n\n  #{url}\n")

          {:error, changeset} ->
            Mix.shell().error("Failed to create share token: #{inspect(changeset.errors)}")
        end
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix fence.gen_share_token user@email.com")
  end
end
