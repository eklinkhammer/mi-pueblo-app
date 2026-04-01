defmodule Fence.Notifications.MemberNotificationPreference do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "member_notification_preferences" do
    field :notify, :boolean, default: true
    field :notify_home, :boolean, default: true

    belongs_to :observer, Fence.Accounts.User
    belongs_to :subject, Fence.Accounts.User
    belongs_to :group, Fence.Groups.Group

    timestamps(type: :utc_datetime)
  end

  def changeset(pref, attrs) do
    pref
    |> cast(attrs, [:observer_id, :subject_id, :group_id, :notify, :notify_home])
    |> validate_required([:observer_id, :subject_id, :group_id])
    |> unique_constraint([:observer_id, :subject_id, :group_id])
    |> foreign_key_constraint(:observer_id)
    |> foreign_key_constraint(:subject_id)
    |> foreign_key_constraint(:group_id)
  end
end
