defmodule Fence.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "groups" do
    field :name, :string

    belongs_to :created_by, Fence.Accounts.User
    has_many :memberships, Fence.Groups.Membership
    has_many :members, through: [:memberships, :user]
    has_many :invites, Fence.Groups.Invite

    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :created_by_id])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
  end
end
