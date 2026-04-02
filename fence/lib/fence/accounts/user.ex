defmodule Fence.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :display_name, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :google_id, :string
    field :locale, :string, default: "en"

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :display_name, :password])
    |> validate_required([:email, :display_name, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 8)
    |> validate_length(:display_name, min: 1, max: 100)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :locale])
    |> validate_length(:display_name, min: 1, max: 100)
    |> validate_inclusion(:locale, ["en", "es"])
  end

  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :display_name, :google_id])
    |> validate_required([:email, :display_name, :google_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:display_name, min: 1, max: 100)
    |> unique_constraint(:email)
    |> unique_constraint(:google_id)
  end

  def link_google_changeset(user, attrs) do
    user
    |> cast(attrs, [:google_id])
    |> validate_required([:google_id])
    |> unique_constraint(:google_id)
  end

  defp put_password_hash(%{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
