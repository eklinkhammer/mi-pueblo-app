defmodule Fence.Accounts do
  import Ecto.Query
  alias Fence.Repo
  alias Fence.Accounts.{User, Token}

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(email, password) do
    user = Repo.get_by(User, email: email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
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
end
