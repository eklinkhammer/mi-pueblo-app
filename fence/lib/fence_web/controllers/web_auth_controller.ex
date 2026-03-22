defmodule FenceWeb.WebAuthController do
  use FenceWeb, :controller

  alias Fence.Accounts

  def register(conn, %{"email" => email, "display_name" => display_name, "password" => password}) do
    case Accounts.register_user(%{
           "email" => email,
           "display_name" => display_name,
           "password" => password
         }) do
      {:ok, user} ->
        {:ok, share_token} = Accounts.create_share_token(user.id, label: "web")

        conn
        |> put_session(:share_token, share_token.token)
        |> redirect(to: ~p"/web/map")

      {:error, changeset} ->
        message =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

        conn
        |> put_flash(:error, "Registration failed: #{message}")
        |> redirect(to: ~p"/web/register")
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate(email, password) do
      {:ok, user} ->
        {:ok, share_token} = Accounts.create_share_token(user.id, label: "web")

        conn
        |> put_session(:share_token, share_token.token)
        |> redirect(to: ~p"/web/map")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/web/login")
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end
end
