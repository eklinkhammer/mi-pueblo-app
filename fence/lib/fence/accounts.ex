defmodule Fence.Accounts do
  import Ecto.Query
  alias Fence.Accounts.{ShareToken, Token, User}
  alias Fence.Repo

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
end
