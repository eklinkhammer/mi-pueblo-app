defmodule Fence.Integration.SubscriptionEnforcementTest do
  use Fence.DataCase, async: true

  alias Fence.{Groups, Subscriptions}
  alias Fence.Subscriptions.Subscription

  import Fence.Factory

  describe "group creation limit enforcement" do
    test "free tier user cannot create a second group" do
      user = create_user()
      create_group(user, %{"name" => "Group 1"})

      refute Subscriptions.can_create_group?(user.id)
    end

    test "elder tier user can create up to 3 groups" do
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

    test "leader tier user has unlimited groups" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_leader", status: "active"})
      |> Repo.update!()

      for i <- 1..10 do
        create_group(user, %{"name" => "Group #{i}"})
      end

      assert Subscriptions.can_create_group?(user.id)
    end
  end

  describe "geofence creation limit enforcement" do
    test "free tier blocked on 4th geofence" do
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

      for i <- 1..10 do
        create_geofence(group, user, %{"name" => "Fence #{i}"})
      end

      assert Subscriptions.can_create_geofence?(group.id)
    end

    test "geofence limit is based on group creator's tier, not requesting user's" do
      creator = create_user()
      member = create_user()

      group = create_group(creator)

      # Join member
      {:ok, invite} = Groups.get_or_create_invite(group.id, creator.id)
      {:ok, _} = Groups.join_by_invite_code(member.id, invite.code)

      # Creator is free tier, create 3 geofences
      for i <- 1..3 do
        create_geofence(group, creator, %{"name" => "Fence #{i}"})
      end

      # Even if member tries, the group's limit is based on creator's tier
      refute Subscriptions.can_create_geofence?(group.id)

      # Upgrade creator to elder
      {:ok, sub} = Subscriptions.get_or_create_subscription(creator.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      # Now geofence creation is allowed
      assert Subscriptions.can_create_geofence?(group.id)
    end
  end

  describe "member limit enforcement" do
    test "free tier blocks 11th member via join_by_invite_code" do
      creator = create_user()
      group = create_group(creator)

      # Add 9 more members (creator + 9 = 10)
      for _ <- 1..9 do
        member = create_user()

        %Groups.Membership{}
        |> Groups.Membership.changeset(%{
          user_id: member.id,
          group_id: group.id,
          role: "member"
        })
        |> Repo.insert!()
      end

      # 11th member should be blocked
      joiner = create_user()
      {:ok, invite} = Groups.get_or_create_invite(group.id, creator.id)
      assert {:error, :member_limit_reached} = Groups.join_by_invite_code(joiner.id, invite.code)
    end

    test "free tier blocks 11th member via anonymous_join" do
      creator = create_user()
      group = create_group(creator)

      for _ <- 1..9 do
        member = create_user()

        %Groups.Membership{}
        |> Groups.Membership.changeset(%{
          user_id: member.id,
          group_id: group.id,
          role: "member"
        })
        |> Repo.insert!()
      end

      {:ok, invite} = Groups.get_or_create_invite(group.id, creator.id)

      assert {:error, :member_limit_reached} =
               Groups.anonymous_join(invite.code, %{"display_name" => "Anon"})
    end

    test "elder tier allows up to 50 members" do
      creator = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(creator.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      group = create_group(creator)

      # Add 9 more members (still well under 50)
      for _ <- 1..9 do
        member = create_user()

        %Groups.Membership{}
        |> Groups.Membership.changeset(%{
          user_id: member.id,
          group_id: group.id,
          role: "member"
        })
        |> Repo.insert!()
      end

      assert Subscriptions.can_add_member?(group.id)
    end
  end

  describe "downgrade behavior" do
    test "existing groups remain after subscription expires" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      g1 = create_group(user, %{"name" => "G1"})
      g2 = create_group(user, %{"name" => "G2"})

      # Expire subscription
      Repo.get_by!(Subscription, user_id: user.id)
      |> Subscription.changeset(%{status: "expired"})
      |> Repo.update!()

      # Groups still exist
      assert Groups.get_group(g1.id)
      assert Groups.get_group(g2.id)

      # But user can't create new groups
      refute Subscriptions.can_create_group?(user.id)
    end

    test "existing geofences remain after subscription expires" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      group = create_group(user)

      for i <- 1..5 do
        create_geofence(group, user, %{"name" => "Fence #{i}"})
      end

      # Expire
      Repo.get_by!(Subscription, user_id: user.id)
      |> Subscription.changeset(%{status: "expired"})
      |> Repo.update!()

      # Geofences still exist
      geofences = Fence.Geofences.list_group_geofences(group.id)
      assert length(geofences) == 5

      # But creation is blocked (free tier allows 3, already has 5)
      refute Subscriptions.can_create_geofence?(group.id)
    end

    test "existing members remain after subscription expires" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      group = create_group(user)

      for _ <- 1..15 do
        member = create_user()

        %Groups.Membership{}
        |> Groups.Membership.changeset(%{
          user_id: member.id,
          group_id: group.id,
          role: "member"
        })
        |> Repo.insert!()
      end

      # Expire
      Repo.get_by!(Subscription, user_id: user.id)
      |> Subscription.changeset(%{status: "expired"})
      |> Repo.update!()

      # Members still exist
      members = Groups.list_members(group.id)
      assert length(members) == 16  # creator + 15

      # But adding more is blocked
      refute Subscriptions.can_add_member?(group.id)
    end
  end

  describe "history retention" do
    test "free tier gets 7 days retention" do
      user = create_user()
      assert Subscriptions.history_retention_days(user.id) == 7
    end

    test "paid tiers get 90 days retention" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "active"})
      |> Repo.update!()

      assert Subscriptions.history_retention_days(user.id) == 90
    end

    test "expired subscription falls back to 7 days" do
      user = create_user()
      {:ok, sub} = Subscriptions.get_or_create_subscription(user.id)

      sub
      |> Subscription.changeset(%{tier: "village_elder", status: "expired"})
      |> Repo.update!()

      assert Subscriptions.history_retention_days(user.id) == 7
    end
  end
end
