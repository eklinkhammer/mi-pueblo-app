defmodule FenceWeb.UserSocket do
  use Phoenix.Socket

  channel "group:*", FenceWeb.GroupChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Fence.Accounts.Token.verify_token(token, "access") do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
