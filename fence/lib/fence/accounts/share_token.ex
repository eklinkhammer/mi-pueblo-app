defmodule Fence.Accounts.ShareToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "share_tokens" do
    field :token, :string
    field :label, :string
    field :expires_at, :utc_datetime

    belongs_to :user, Fence.Accounts.User

    timestamps()
  end

  def changeset(share_token, attrs) do
    share_token
    |> cast(attrs, [:user_id, :label, :expires_at])
    |> validate_required([:user_id, :expires_at])
    |> put_token()
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end

  defp put_token(%{data: %{token: nil}} = changeset) do
    put_change(changeset, :token, generate_token())
  end

  defp put_token(changeset), do: changeset

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
