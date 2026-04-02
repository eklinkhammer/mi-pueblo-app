defmodule Fence.Accounts do
  import Ecto.Query
  alias Fence.Accounts.{PasswordResetCode, ShareToken, Token, User}
  alias Fence.Repo
  alias Fence.Workers

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(email, password) do
    user = Repo.get_by(User, email: email)

    cond do
      user && user.password_hash && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def generate_tokens(user) do
    with {:ok, access_token, _claims} <- Token.generate_access_token(user),
         {:ok, refresh_token, _claims} <- Token.generate_refresh_token(user) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token}}
    end
  end

  def refresh_tokens(refresh_token) do
    with {:ok, user_id} <- Token.verify_token(refresh_token, "refresh"),
         %User{} = user <- Repo.get(User, user_id) do
      generate_tokens(user)
    else
      nil -> {:error, :user_not_found}
      error -> error
    end
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    cancel_pending_jobs_for_user(user.id)
    Repo.delete(user)
  end

  defp cancel_pending_jobs_for_user(user_id) do
    user_id_str = to_string(user_id)

    query =
      from(j in Oban.Job,
        where: j.state in ["available", "scheduled", "retryable"],
        where: fragment("?->>'user_id' = ?", j.args, ^user_id_str)
      )

    Oban.cancel_all_jobs(query)
  end

  def register_device_token(user_id, token, platform) do
    alias Fence.Accounts.DeviceToken

    %DeviceToken{}
    |> DeviceToken.changeset(%{user_id: user_id, token: token, platform: platform})
    |> Repo.insert(
      on_conflict: {:replace, [:token, :updated_at]},
      conflict_target: [:user_id, :platform]
    )
  end

  def get_device_tokens(user_id) do
    from(dt in Fence.Accounts.DeviceToken, where: dt.user_id == ^user_id)
    |> Repo.all()
  end

  # Google OAuth

  def authenticate_google(%{google_id: google_id, email: email, name: name}) do
    case Repo.get_by(User, google_id: google_id) do
      %User{} = user ->
        {:ok, user}

      nil ->
        case Repo.get_by(User, email: email) do
          %User{} = user ->
            user
            |> User.link_google_changeset(%{google_id: google_id})
            |> Repo.update()

          nil ->
            %User{}
            |> User.oauth_changeset(%{email: email, display_name: name, google_id: google_id})
            |> Repo.insert()
        end
    end
  end

  # Share tokens

  def create_share_token(user_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    label = Keyword.get(opts, :label)
    expires_at = DateTime.utc_now() |> DateTime.add(days * 86_400) |> DateTime.truncate(:second)

    %ShareToken{}
    |> ShareToken.changeset(%{user_id: user_id, label: label, expires_at: expires_at})
    |> Repo.insert()
  end

  def get_user_by_share_token(token) do
    now = DateTime.utc_now()

    query =
      from st in ShareToken,
        where: st.token == ^token and st.expires_at > ^now,
        join: u in User,
        on: u.id == st.user_id,
        select: u

    Repo.one(query)
  end

  def list_share_tokens(user_id) do
    from(st in ShareToken, where: st.user_id == ^user_id, order_by: [desc: :inserted_at])
    |> Repo.all()
  end

  def delete_share_token(id) do
    case Repo.get(ShareToken, id) do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

  # Password reset

  def request_password_reset(email) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        invalidate_old_reset_codes(user.id)
        code = PasswordResetCode.generate_code()

        %PasswordResetCode{}
        |> PasswordResetCode.changeset(%{user_id: user.id, code: code})
        |> Repo.insert!()

        %{user_id: user.id, code: code}
        |> Workers.PasswordResetEmailWorker.new()
        |> Oban.insert()

      nil ->
        Bcrypt.no_user_verify()
    end

    :ok
  end

  def reset_password(email, code, new_password) do
    Repo.transaction(fn ->
      case verify_reset_code(email, code) do
        {:ok, reset_code, user} ->
          user
          |> User.password_changeset(%{password: new_password})
          |> Repo.update!()

          reset_code
          |> Ecto.Changeset.change(used_at: DateTime.utc_now() |> DateTime.truncate(:second))
          |> Repo.update!()

          user

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  defp verify_reset_code(email, code) do
    with %User{} = user <- Repo.get_by(User, email: email),
         %PasswordResetCode{} = reset_code <- get_latest_reset_code(user.id) do
      cond do
        PasswordResetCode.used?(reset_code) ->
          {:error, :code_already_used}

        PasswordResetCode.expired?(reset_code) ->
          {:error, :code_expired}

        PasswordResetCode.max_attempts_exceeded?(reset_code) ->
          {:error, :max_attempts}

        Bcrypt.verify_pass(code, reset_code.code_hash) ->
          {:ok, reset_code, user}

        true ->
          increment_attempts(reset_code)
          {:error, :invalid_code}
      end
    else
      nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_code}
    end
  end

  defp get_latest_reset_code(user_id) do
    from(r in PasswordResetCode,
      where: r.user_id == ^user_id and is_nil(r.used_at),
      order_by: [desc: :inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp invalidate_old_reset_codes(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(r in PasswordResetCode,
      where: r.user_id == ^user_id and is_nil(r.used_at)
    )
    |> Repo.update_all(set: [used_at: now])
  end

  defp increment_attempts(reset_code) do
    reset_code
    |> Ecto.Changeset.change(attempts: reset_code.attempts + 1)
    |> Repo.update()
  end
end
