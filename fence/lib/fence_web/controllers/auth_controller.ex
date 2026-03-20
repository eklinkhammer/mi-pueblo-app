defmodule FenceWeb.AuthController do
  use FenceWeb, :controller

  alias Fence.Accounts

  def register(conn, %{"email" => _, "password" => _, "display_name" => _} = params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        {:ok, tokens} = Accounts.generate_tokens(user)

        conn
        |> put_status(:created)
        |> json(%{
          user: user_json(user),
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: email, password, display_name"})
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate(email, password) do
      {:ok, user} ->
        {:ok, tokens} = Accounts.generate_tokens(user)

        json(conn, %{
          user: user_json(user),
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.refresh_tokens(refresh_token) do
      {:ok, tokens} ->
        json(conn, %{
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        })

      {:error, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid refresh token"})
    end
  end

  def me(conn, _params) do
    json(conn, %{user: user_json(conn.assigns.current_user)})
  end

  def update_me(conn, params) do
    case Accounts.update_user(conn.assigns.current_user, params) do
      {:ok, user} ->
        json(conn, %{user: user_json(user)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def register_device_token(conn, %{"token" => token, "platform" => platform}) do
    user = conn.assigns.current_user

    case Accounts.register_device_token(user.id, token, platform) do
      {:ok, _device_token} ->
        json(conn, %{ok: true})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      inserted_at: user.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
