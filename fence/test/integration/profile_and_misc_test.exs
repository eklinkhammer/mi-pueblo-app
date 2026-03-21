defmodule Fence.Integration.ProfileAndMiscTest do
  @moduledoc """
  Tests remaining API surface gaps: group locations, profile updates,
  device token registration, and expired invite codes.
  """

  use Fence.IntegrationCase, async: false

  import Ecto.Query

  @sf_lat 37.7749
  @sf_lng -122.4194

  @oakland_lat 37.8044
  @oakland_lng -122.2712

  @nyc_lat 40.7128
  @nyc_lng -74.0060

  describe "GET /groups/:id/locations" do
    test "returns last location per member with correct fields", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      {_carol, token_c, _} = register_via_api(conn, %{"display_name" => "Carol"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)
      conn_c = authed_conn_from_token(conn, token_c)

      # Create group, all three join
      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Locations Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite1 = conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_b
      |> post("/api/v1/groups/join", %{"invite_code" => invite1["invite"]["code"]})
      |> json_response(200)

      invite2 = conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_c
      |> post("/api/v1/groups/join", %{"invite_code" => invite2["invite"]["code"]})
      |> json_response(200)

      # Each reports a location at different coordinates
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0,
        "speed" => 1.5,
        "battery_level" => 85.0
      })
      |> json_response(200)

      conn_b
      |> post("/api/v1/location", %{
        "latitude" => @oakland_lat,
        "longitude" => @oakland_lng,
        "accuracy" => 20.0,
        "speed" => 0.0,
        "battery_level" => 50.0
      })
      |> json_response(200)

      conn_c
      |> post("/api/v1/location", %{
        "latitude" => @nyc_lat,
        "longitude" => @nyc_lng,
        "accuracy" => 5.0,
        "speed" => 3.0,
        "battery_level" => 92.0
      })
      |> json_response(200)

      # Drain so geofence checks complete
      drain_oban()

      # Fetch group locations
      resp =
        conn_a
        |> get("/api/v1/groups/#{group_id}/locations")
        |> json_response(200)

      locations = resp["locations"]
      assert length(locations) == 3

      # Each location has required fields
      for loc <- locations do
        assert is_binary(loc["user_id"])
        assert is_binary(loc["display_name"])
        assert is_number(loc["latitude"])
        assert is_number(loc["longitude"])
        assert Map.has_key?(loc, "accuracy")
        assert Map.has_key?(loc, "speed")
        assert Map.has_key?(loc, "battery_level")
        assert Map.has_key?(loc, "updated_at")
      end

      # Check specific coordinates by display_name
      alice_loc = Enum.find(locations, &(&1["display_name"] == "Alice"))
      assert_in_delta alice_loc["latitude"], @sf_lat, 0.001
      assert_in_delta alice_loc["longitude"], @sf_lng, 0.001

      bob_loc = Enum.find(locations, &(&1["display_name"] == "Bob"))
      assert_in_delta bob_loc["latitude"], @oakland_lat, 0.001

      carol_loc = Enum.find(locations, &(&1["display_name"] == "Carol"))
      assert_in_delta carol_loc["latitude"], @nyc_lat, 0.001
    end

    test "returns only the most recent location per user", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Latest Only"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Alice reports two locations (sleep ensures different inserted_at seconds)
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      Process.sleep(1100)

      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @nyc_lat,
        "longitude" => @nyc_lng,
        "accuracy" => 5.0
      })
      |> json_response(200)

      drain_oban()

      resp =
        conn_a
        |> get("/api/v1/groups/#{group_id}/locations")
        |> json_response(200)

      # Only one entry for Alice (the latest)
      assert length(resp["locations"]) == 1

      loc = hd(resp["locations"])
      assert_in_delta loc["latitude"], @nyc_lat, 0.001
      assert_in_delta loc["longitude"], @nyc_lng, 0.001
    end
  end

  describe "PUT /me updates profile" do
    test "update display_name, verify via GET /me, and broadcasts use new name", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      # Update display_name
      update_resp =
        conn_a
        |> put("/api/v1/me", %{"display_name" => "Alice Updated"})
        |> json_response(200)

      assert update_resp["user"]["display_name"] == "Alice Updated"

      # Verify via GET /me
      me_resp =
        conn_a
        |> get("/api/v1/me")
        |> json_response(200)

      assert me_resp["user"]["display_name"] == "Alice Updated"

      # Create a group, have Bob join and listen on channel
      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # Alice reports location — broadcast should use updated display_name
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      assert_broadcast "location:updated", %{display_name: "Alice Updated"}
    end
  end

  describe "POST /me/device-token" do
    test "register and upsert device tokens", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)
      alice_user = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Alice")

      # Register iOS token
      conn_a
      |> post("/api/v1/me/device-token", %{
        "token" => "ios-token-abc123",
        "platform" => "ios"
      })
      |> json_response(200)

      tokens = Fence.Accounts.get_device_tokens(alice_user.id)
      assert length(tokens) == 1
      assert hd(tokens).platform == "ios"
      assert hd(tokens).token == "ios-token-abc123"

      # Upsert: same platform, new token (replaces)
      conn_a
      |> post("/api/v1/me/device-token", %{
        "token" => "ios-token-new456",
        "platform" => "ios"
      })
      |> json_response(200)

      tokens = Fence.Accounts.get_device_tokens(alice_user.id)
      ios_tokens = Enum.filter(tokens, &(&1.platform == "ios"))
      assert length(ios_tokens) == 1
      assert hd(ios_tokens).token == "ios-token-new456"

      # Register Android token (second entry, different platform)
      conn_a
      |> post("/api/v1/me/device-token", %{
        "token" => "android-token-xyz789",
        "platform" => "android"
      })
      |> json_response(200)

      tokens = Fence.Accounts.get_device_tokens(alice_user.id)
      assert length(tokens) == 2
      platforms = Enum.map(tokens, & &1.platform) |> Enum.sort()
      assert platforms == ["android", "ios"]
    end
  end

  describe "expired invite code" do
    test "returns 410 with 'Invite code expired' message", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Invite Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      invite_code = invite_resp["invite"]["code"]

      # Expire the invite by setting expires_at to past
      past = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      from(i in Fence.Groups.Invite, where: i.code == ^invite_code)
      |> Fence.Repo.update_all(set: [expires_at: past])

      # Bob tries to join with expired invite
      resp =
        conn_b
        |> post("/api/v1/groups/join", %{"invite_code" => invite_code})
        |> json_response(410)

      assert resp["error"] =~ "expired"
    end
  end

  defp setup_group_with_invite(conn_a, conn_b) do
    group_resp =
      conn_a |> post("/api/v1/groups", %{"name" => "Test Group"}) |> json_response(201)

    group_id = group_resp["group"]["id"]

    invite_resp =
      conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

    conn_b
    |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
    |> json_response(200)

    group_resp["group"]
  end
end
