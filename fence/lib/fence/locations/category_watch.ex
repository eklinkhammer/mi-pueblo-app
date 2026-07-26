defmodule Fence.Locations.CategoryWatch do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "category_watches" do
    field :category, :string
    field :active, :boolean, default: true
    field :throttle_seconds, :integer, default: 3600

    belongs_to :watcher, Fence.Accounts.User
    belongs_to :watched_user, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(watch, attrs) do
    watch
    |> cast(attrs, [:watcher_id, :watched_user_id, :category, :active, :throttle_seconds])
    |> validate_required([:watcher_id, :watched_user_id, :category])
    |> unique_constraint([:watcher_id, :watched_user_id, :category])
  end
end
