defmodule Fence.SubscriptionsTest do
  use Fence.DataCase, async: true

  alias Fence.Subscriptions
  alias Fence.Subscriptions.Subscription

  import Fence.Factory

  describe "get_or_create_subscription/1" do
    test "creates a new free-tier subscription" do
      user = create_user()
      assert {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)
      assert sub.tier == "village_member"
      assert sub.status == "active"
      assert sub.user_id == user.id
    end

    test "returns existing subscription on second call" do
      user = create_user()
      {:ok, sub1} = Subscriptions.get_or_create_subscription(user.id)
      {:ok, sub2} = Subscriptions.get_or_create_subscription(user.id)
      assert sub1.id == sub2.id
    end
  end

  describe "active_tier/1" do
    test "returns village_member for user with no subscription" do
      user = create_user()
      assert Subscriptions.active_tier(user.id) == "village_member"
    end

    test "returns the tier for active subscription" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      assert Subscriptions.active_tier(user.id) == "village_elder"
    end

    test "returns village_member for expired subscription" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "expired"})
      |> Repo.update!()

      assert Subscriptions.active_tier(user.id) == "village_member"
    end

    test "returns tier for grace_period subscription" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_leader", status: "grace_period"})
      |> Repo.update!()

      assert Subscriptions.active_tier(user.id) == "village_leader"
    end
  end

  describe "can_create_group?/1" do
    test "free tier can create 1 group" do
      user = create_user()
      assert Subscriptions.can_create_group?(user.id)
    end

    test "free tier cannot create 2nd group" do
      user = create_user()
      create_group(user, %{"name" => "Group 1"})
      refute Subscriptions.can_create_group?(user.id)
    end

    test "elder tier can create up to 3 groups" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      create_group(user, %{"name" => "Group 1"})
      create_group(user, %{"name" => "Group 2"})
      assert Subscriptions.can_create_group?(user.id)

      create_group(user, %{"name" => "Group 3"})
      refute Subscriptions.can_create_group?(user.id)
    end

    test "leader tier has unlimited groups" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_leader", status: "active"})
      |> Repo.update!()

      for i <- 1..5 do
        create_group(user, %{"name" => "Group #{i}"})
      end

      assert Subscriptions.can_create_group?(user.id)
    end
  end

  describe "can_add_member?/1" do
    test "free tier allows up to 10 members" do
      creator = create_user()
      group = create_group(creator)

      # Creator is already member 1
      assert Subscriptions.can_add_member?(group.id)
    end

    test "free tier blocks member 11" do
      creator = create_user()
      group = create_group(creator)

      # Add 9 more members (creator + 9 = 10)
      for _ <- 1..9 do
        member = create_user()

        %Fence.Groups.Membership{}
        |> Fence.Groups.Membership.changeset(%{
          user_id: member.id,
          group_id: group.id,
          role: "member"
        })
        |> Repo.insert!()
      end

      refute Subscriptions.can_add_member?(group.id)
    end
  end

  describe "can_create_geofence?/1" do
    test "free tier allows up to 3 geofences" do
      user = create_user()
      group = create_group(user)
      assert Subscriptions.can_create_geofence?(group.id)
    end

    test "free tier blocks 4th geofence" do
      user = create_user()
      group = create_group(user)

      for i <- 1..3 do
        create_geofence(group, user, %{"name" => "Fence #{i}"})
      end

      refute Subscriptions.can_create_geofence?(group.id)
    end

    test "elder tier has unlimited geofences" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      group = create_group(user)

      for i <- 1..5 do
        create_geofence(group, user, %{"name" => "Fence #{i}"})
      end

      assert Subscriptions.can_create_geofence?(group.id)
    end
  end

  describe "history_retention_days/1" do
    test "free tier gets 7 days" do
      user = create_user()
      assert Subscriptions.history_retention_days(user.id) == 7
    end

    test "elder tier gets 90 days" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      assert Subscriptions.history_retention_days(user.id) == 90
    end
  end

  describe "count helpers" do
    test "count_created_groups counts only groups created by user" do
      user1 = create_user()
      user2 = create_user()
      create_group(user1, %{"name" => "G1"})
      create_group(user1, %{"name" => "G2"})
      create_group(user2, %{"name" => "G3"})

      assert Subscriptions.count_created_groups(user1.id) == 2
      assert Subscriptions.count_created_groups(user2.id) == 1
    end

    test "count_members counts all memberships in group" do
      creator = create_user()
      group = create_group(creator)

      member = create_user()

      %Fence.Groups.Membership{}
      |> Fence.Groups.Membership.changeset(%{
        user_id: member.id,
        group_id: group.id,
        role: "member"
      })
      |> Repo.insert!()

      assert Subscriptions.count_members(group.id) == 2
    end
  end

  describe "product_id_to_tier/1" do
    test "maps known product IDs to tiers" do
      assert Subscriptions.product_id_to_tier("fence_elder_monthly") == "village_elder"
      assert Subscriptions.product_id_to_tier("fence_leader_monthly") == "village_leader"
    end

    test "unknown product defaults to village_member" do
      assert Subscriptions.product_id_to_tier("unknown_product") == "village_member"
    end
  end

  describe "process_webhook/1" do
    test "INITIAL_PURCHASE upgrades tier" do
      user = create_user()
      {:ok, _} = Subscriptions.get_or_create_subscription(user.id)

      assert {:ok, sub} =
               Subscriptions.process_webhook(%{
                 "event" => "INITIAL_PURCHASE",
                 "app_user_id" => user.id,
                 "product_id" => "fence_elder_monthly",
                 "original_app_user_id" => "rc_#{user.id}",
                 "entitlement_id" => "elder",
                 "store" => "app_store",
                 "period_start" => nil,
                 "period_end" => nil,
                 "expiration_at" => nil
               })

      assert sub.tier == "village_elder"
      assert sub.status == "active"
    end

    test "EXPIRATION sets status to expired" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      assert {:ok, updated} =
               Subscriptions.process_webhook(%{
                 "event" => "EXPIRATION",
                 "app_user_id" => user.id
               })

      assert updated.status == "expired"
    end

    test "CANCELLATION sets status to cancelled" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      assert {:ok, updated} =
               Subscriptions.process_webhook(%{
                 "event" => "CANCELLATION",
                 "app_user_id" => user.id
               })

      assert updated.status == "cancelled"
    end

    test "BILLING_ISSUE sets grace_period" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      assert {:ok, updated} =
               Subscriptions.process_webhook(%{
                 "event" => "BILLING_ISSUE",
                 "app_user_id" => user.id
               })

      assert updated.status == "grace_period"
    end

    test "unknown event returns :ok" do
      assert :ok = Subscriptions.process_webhook(%{"event" => "SOME_UNKNOWN_EVENT"})
    end
  end

  describe "Subscription schema" do
    test "valid changeset" do
      user = create_user()

      changeset =
        Subscription.changeset(%Subscription{}, %{
          user_id: user.id,
          tier: "village_member",
          status: "active"
        })

      assert changeset.valid?
    end

    test "rejects invalid tier" do
      user = create_user()

      changeset =
        Subscription.changeset(%Subscription{}, %{
          user_id: user.id,
          tier: "invalid_tier",
          status: "active"
        })

      refute changeset.valid?
      assert %{tier: _} = errors_on(changeset)
    end

    test "rejects invalid status" do
      user = create_user()

      changeset =
        Subscription.changeset(%Subscription{}, %{
          user_id: user.id,
          tier: "village_member",
          status: "invalid_status"
        })

      refute changeset.valid?
      assert %{status: _} = errors_on(changeset)
    end
  end
end
