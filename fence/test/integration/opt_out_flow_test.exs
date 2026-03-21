defmodule Fence.Integration.OptOutFlowTest do
  use Fence.IntegrationCase, async: false

  @sf_lat 37.7749
  @sf_lng -122.4194

  describe "opted-out user not detected" do
    test "opted-out user does not trigger geofence:entered", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      # B creates geofence, subscribes
      geofence_resp =
        conn_b
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Home",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })

      # A opts out of this geofence
      conn_a
      |> post("/api/v1/geofences/#{geofence_id}/opt-out")
      |> json_response(200)

      # B joins channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A reports location inside the geofence
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Should get location:updated broadcast (that still happens)
      assert_broadcast "location:updated", _payload

      # Should NOT get geofence:entered (because A opted out)
      refute_broadcast "geofence:entered", _any

      # Verify no geofence state
      user_a = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Alice")
      state_ids = Fence.Locations.get_user_geofence_ids(user_a.id)
      assert MapSet.size(state_ids) == 0
    end
  end

  describe "remove opt-out restores detection" do
    test "deleting opt-out allows geofence detection again", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      geofence_resp =
        conn_b
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Home",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })

      # A opts out, then removes opt-out
      conn_a
      |> post("/api/v1/geofences/#{geofence_id}/opt-out")
      |> json_response(200)

      conn_a
      |> delete("/api/v1/geofences/#{geofence_id}/opt-out")
      |> json_response(200)

      # B joins channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A reports location inside the geofence
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # NOW geofence:entered should fire
      assert_broadcast "geofence:entered", %{geofence_id: ^geofence_id}
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
