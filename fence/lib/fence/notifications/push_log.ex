defmodule Fence.Notifications.PushLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "push_logs" do
    field :event, :string
    field :status, :string, default: "sent"

    belongs_to :recipient, Fence.Accounts.User
    belongs_to :triggering_user, Fence.Accounts.User
    belongs_to :geofence, Fence.Geofences.Geofence

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:recipient_id, :triggering_user_id, :geofence_id, :event, :status])
    |> validate_required([:recipient_id, :event])
    |> validate_inclusion(:event, ["entered", "exited"])
    |> validate_inclusion(:status, ["sent", "throttled", "failed"])
  end
end
