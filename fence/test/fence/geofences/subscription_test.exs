defmodule Fence.Geofences.SubscriptionTest do
  use Fence.DataCase, async: true

  alias Fence.Geofences.Subscription

  @valid_attrs %{user_id: Ecto.UUID.generate(), geofence_id: Ecto.UUID.generate()}

  describe "changeset/2" do
    test "valid attrs" do
      changeset = Subscription.changeset(%Subscription{}, @valid_attrs)
      assert changeset.valid?
    end

    test "defaults notify_on_entry to true" do
      sub = %Subscription{}
      assert sub.notify_on_entry == true
    end

    test "defaults notify_on_exit to true" do
      sub = %Subscription{}
      assert sub.notify_on_exit == true
    end

    test "defaults throttle_seconds to 300" do
      sub = %Subscription{}
      assert sub.throttle_seconds == 300
    end

    test "validates throttle_seconds >= 0" do
      changeset =
        Subscription.changeset(%Subscription{}, Map.put(@valid_attrs, :throttle_seconds, -1))

      assert %{throttle_seconds: [_]} = errors_on(changeset)
    end

    test "defaults blacklisted_user_ids to empty list" do
      sub = %Subscription{}
      assert sub.blacklisted_user_ids == []
    end
  end
end
