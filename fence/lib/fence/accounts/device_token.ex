defmodule Fence.Accounts.DeviceToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_tokens" do
    field :token, :string
    field :platform, :string

    belongs_to :user, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [:user_id, :token, :platform])
    |> validate_required([:user_id, :token, :platform])
    |> validate_inclusion(:platform, ["android", "ios"])
    |> foreign_key_constraint(:user_id)
  end
end
