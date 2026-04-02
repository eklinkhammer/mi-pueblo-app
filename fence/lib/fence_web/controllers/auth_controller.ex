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
    |> json(%{
      error: %{
        code: "missing_fields",
        message: "Missing required fields: email, password, display_name"
      }
    })
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
        |> json(%{error: %{code: "invalid_credentials", message: "Invalid email or password"}})
    end
  end

  def google(conn, %{"id_token" => id_token}) do
    google_token_mod =
      Application.get_env(:fence, :google_token_module, Fence.Accounts.GoogleToken)

    case google_token_mod.verify_and_extract(id_token) do
      {:ok, claims} ->
        case Accounts.authenticate_google(claims) do
          {:ok, user} ->
            {:ok, tokens} = Accounts.generate_tokens(user)

            json(conn, %{
              user: user_json(user),
              access_token: tokens.access_token,
              refresh_token: tokens.refresh_token
            })

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "invalid_google_token", message: "Invalid Google ID token"}})
    end
  end

  def google(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_fields", message: "Missing required field: id_token"}})
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
        |> json(%{error: %{code: "invalid_refresh_token", message: "Invalid refresh token"}})
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

  def delete_me(conn, _params) do
    case Accounts.delete_user(conn.assigns.current_user) do
      {:ok, _user} ->
        send_resp(conn, :no_content, "")

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{code: "deletion_failed", message: "Failed to delete account"}})
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

  def forgot_password(conn, %{"email" => email}) do
    Accounts.request_password_reset(email)
    json(conn, %{message: "If that email is registered, a reset code has been sent."})
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_fields", message: "Missing required field: email"}})
  end

  def reset_password(conn, %{"email" => email, "code" => code, "password" => password}) do
    case Accounts.reset_password(email, code, password) do
      {:ok, user} ->
        {:ok, tokens} = Accounts.generate_tokens(user)

        json(conn, %{
          user: user_json(user),
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token
        })

      {:error, :invalid_code} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "invalid_code", message: "Invalid reset code"}})

      {:error, :code_expired} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "code_expired", message: "Reset code has expired"}})

      {:error, :max_attempts} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "max_attempts", message: "Too many incorrect attempts"}})

      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "invalid_code", message: "Invalid reset code"}})
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_fields", message: "Missing required fields: email, code, password"}})
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      locale: user.locale,
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
