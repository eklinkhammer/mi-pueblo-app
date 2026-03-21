defmodule FenceWeb.WebAuth do
  @moduledoc """
  LiveView on_mount hook for share token authentication.
  Reads the share token from session and assigns current_user.
  """
  import Phoenix.LiveView
  import Phoenix.Component
  alias Fence.Accounts

  def on_mount(:ensure_authenticated, _params, session, socket) do
    token = session["share_token"]

    case token && Accounts.get_user_by_share_token(token) do
      %Accounts.User{} = user ->
        {:cont, assign(socket, :current_user, user)}

      _ ->
        {:halt, redirect(socket, to: "/web/unauthorized")}
    end
  end
end
