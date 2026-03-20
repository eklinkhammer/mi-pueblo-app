defmodule Fence.Groups.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "memberships" do
    field :role, :string, default: "member"

    belongs_to :user, Fence.Accounts.User
    belongs_to :group, Fence.Groups.Group

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :group_id, :role])
    |> validate_required([:user_id, :group_id])
    |> validate_inclusion(:role, ["admin", "member"])
    |> unique_constraint([:user_id, :group_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:group_id)
  end
end
