defmodule Fence.Groups.Invite do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "invites" do
    field :code, :string
    field :expires_at, :utc_datetime

    belongs_to :group, Fence.Groups.Group
    belongs_to :created_by, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:group_id, :created_by_id, :expires_at])
    |> validate_required([:group_id])
    |> put_code()
    |> put_default_expiry()
    |> unique_constraint(:code)
  end

  defp put_code(changeset) do
    if get_field(changeset, :code) do
      changeset
    else
      put_change(changeset, :code, generate_code())
    end
  end

  defp put_default_expiry(changeset) do
    if get_field(changeset, :expires_at) do
      changeset
    else
      # Default: 7 days from now
      expires =
        DateTime.utc_now() |> DateTime.add(7 * 24 * 3600, :second) |> DateTime.truncate(:second)

      put_change(changeset, :expires_at, expires)
    end
  end

  defp generate_code do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false) |> String.slice(0, 8)
  end
end
