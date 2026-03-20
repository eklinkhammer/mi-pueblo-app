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
    |> cast(attrs, [:display_name])
    |> validate_length(:display_name, min: 1, max: 100)
  end

  defp put_password_hash(%{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
