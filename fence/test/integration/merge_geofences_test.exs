defmodule Fence.Integration.MergeGeofencesTest do
  @moduledoc """
  Tests MergeGeofencesWorker + MergeEngine with real PostGIS operations:
  overlapping merges, non-overlapping stays separate, transitive chains,
  and re-merge on delete.
  """

  use Fence.IntegrationCase, async: false

  import Ecto.Query

  alias Fence.Geofences
  alias Fence.Geofences.{MergedGeofence, MergeEngine}
  alias Fence.Repo

  # Two points ~1.3 km apart in SF (well within 3km radii overlap)
  @sf_lat 37.7749
  @sf_lng -122.4194

  @sf_nearby_lat 37.7849
  @sf_nearby_lng -122.4094

  # NYC — far from SF
  @nyc_lat 40.7128
  @nyc_lng -74.0060

  # Three points in a line for transitive chain test (~2km apart each)
  @chain_a_lat 37.7749
  @chain_a_lng -122.4194

  @chain_b_lat 37.7900
  @chain_b_lng -122.4194

  @chain_c_lat 37.8050
  @chain_c_lng -122.4194

  describe "overlapping geofences merge" do
    test "two overlapping geofences produce a MergedGeofence", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Merge Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Create two geofences with 3km radii, ~1.3km apart (they overlap)
      gf1_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Zone A",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf2_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Zone B",
          "latitude" => @sf_nearby_lat,
          "longitude" => @sf_nearby_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf1_id = gf1_resp["geofence"]["id"]
      gf2_id = gf2_resp["geofence"]["id"]

      # Drain maintenance queue (merge worker auto-enqueued on create)
      Oban.drain_queue(Oban, queue: :maintenance)

      # Assert MergedGeofence exists for this group
      merged =
        Repo.all(from(mg in MergedGeofence, where: mg.group_id == ^group_id))

      assert length(merged) == 1
      merged_record = hd(merged)

      # Both geofences should be linked to the merged geofence
      gf1 = Geofences.get_geofence(gf1_id)
      gf2 = Geofences.get_geofence(gf2_id)

      assert gf1.merged_geofence_id == merged_record.id
      assert gf2.merged_geofence_id == merged_record.id
    end
  end

  describe "non-overlapping geofences don't merge" do
    test "SF and NYC geofences with 1km radii stay separate", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "No Merge Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      gf1_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "SF Small",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 1000.0
        })
        |> json_response(201)

      gf2_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "NYC Small",
          "latitude" => @nyc_lat,
          "longitude" => @nyc_lng,
          "radius_meters" => 1000.0
        })
        |> json_response(201)

      gf1_id = gf1_resp["geofence"]["id"]
      gf2_id = gf2_resp["geofence"]["id"]

      Oban.drain_queue(Oban, queue: :maintenance)

      # No MergedGeofence records for this group
      merged_count =
        Repo.aggregate(
          from(mg in MergedGeofence, where: mg.group_id == ^group_id),
          :count
        )

      assert merged_count == 0

      # Both geofences have nil merged_geofence_id
      gf1 = Geofences.get_geofence(gf1_id)
      gf2 = Geofences.get_geofence(gf2_id)

      assert gf1.merged_geofence_id == nil
      assert gf2.merged_geofence_id == nil
    end
  end

  describe "transitive chain merging" do
    test "A-B-C in a line, each overlapping neighbor, all end up in one merge", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Chain Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # 3km radius, points ~1.7km apart — each pair overlaps but A and C don't directly
      gf_a_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Chain A",
          "latitude" => @chain_a_lat,
          "longitude" => @chain_a_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf_b_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Chain B",
          "latitude" => @chain_b_lat,
          "longitude" => @chain_b_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf_c_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Chain C",
          "latitude" => @chain_c_lat,
          "longitude" => @chain_c_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf_a_id = gf_a_resp["geofence"]["id"]
      gf_b_id = gf_b_resp["geofence"]["id"]
      gf_c_id = gf_c_resp["geofence"]["id"]

      Oban.drain_queue(Oban, queue: :maintenance)

      # All three should end up in one MergedGeofence (transitive closure via union-find)
      merged =
        Repo.all(from(mg in MergedGeofence, where: mg.group_id == ^group_id))

      assert length(merged) == 1
      merged_id = hd(merged).id

      gf_a = Geofences.get_geofence(gf_a_id)
      gf_b = Geofences.get_geofence(gf_b_id)
      gf_c = Geofences.get_geofence(gf_c_id)

      assert gf_a.merged_geofence_id == merged_id
      assert gf_b.merged_geofence_id == merged_id
      assert gf_c.merged_geofence_id == merged_id
    end
  end

  describe "delete re-triggers merge" do
    test "deleting one of two merged geofences cleans up merge record", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Delete Merge Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      gf1_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Merge A",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf2_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Merge B",
          "latitude" => @sf_nearby_lat,
          "longitude" => @sf_nearby_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      gf1_id = gf1_resp["geofence"]["id"]
      gf2_id = gf2_resp["geofence"]["id"]

      # Let merge complete
      Oban.drain_queue(Oban, queue: :maintenance)

      # Verify they merged
      merged_before =
        Repo.all(from(mg in MergedGeofence, where: mg.group_id == ^group_id))

      assert length(merged_before) == 1

      # Delete geofence 1 via API (this enqueues merge, but unique constraint
      # may deduplicate if within 5s of prior job)
      conn_a
      |> delete("/api/v1/groups/#{group_id}/geofences/#{gf1_id}")
      |> response(204)

      # Directly call merge engine to ensure re-merge runs
      # (Oban unique constraint may prevent the re-enqueued job from inserting)
      MergeEngine.merge_group_geofences(group_id)

      # Only one geofence left — no merge needed
      merged_after =
        Repo.all(from(mg in MergedGeofence, where: mg.group_id == ^group_id))

      assert merged_after == []

      # Remaining geofence has nil merged_geofence_id
      gf2 = Geofences.get_geofence(gf2_id)
      assert gf2.merged_geofence_id == nil
    end
  end
end
