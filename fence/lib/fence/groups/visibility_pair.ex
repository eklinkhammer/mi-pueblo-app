defmodule Fence.Groups.VisibilityPair do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "visibility_pairs" do
    field :status, :string, default: "pending"
    field :granted_at, :utc_datetime

    belongs_to :group, Fence.Groups.Group
    belongs_to :user_a, Fence.Accounts.User
    belongs_to :user_b, Fence.Accounts.User
    belongs_to :granted_by, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(pair, attrs) do
    pair
    |> cast(attrs, [:group_id, :user_a_id, :user_b_id, :status, :granted_by_id, :granted_at])
    |> validate_required([:group_id, :user_a_id, :user_b_id])
    |> validate_inclusion(:status, ["pending", "active"])
    |> normalize_user_order()
    |> unique_constraint([:group_id, :user_a_id, :user_b_id])
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:user_a_id)
    |> foreign_key_constraint(:user_b_id)
  end

  defp normalize_user_order(changeset) do
    a = get_field(changeset, :user_a_id)
    b = get_field(changeset, :user_b_id)

    if a && b && a > b do
      changeset
      |> put_change(:user_a_id, b)
      |> put_change(:user_b_id, a)
    else
      changeset
    end
  end
end
