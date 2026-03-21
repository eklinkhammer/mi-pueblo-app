defmodule Fence.Geofences.MergeEngine do
  @moduledoc """
  Merges overlapping geofences within a group using union-find
  and PostGIS spatial operations.
  """

  import Ecto.Query

  alias Fence.Geofences.{Geofence, MergedGeofence}
  alias Fence.Repo

  def merge_group_geofences(group_id) do
    Repo.transaction(fn ->
      # 1. Clear existing merged geofences for this group
      from(mg in MergedGeofence, where: mg.group_id == ^group_id) |> Repo.delete_all()

      # Reset merged_geofence_id on all geofences in group
      from(g in Geofence, where: g.group_id == ^group_id)
      |> Repo.update_all(set: [merged_geofence_id: nil])

      # 2. Load all active geofences
      now = DateTime.utc_now()

      geofences =
        from(g in Geofence,
          where: g.group_id == ^group_id and g.expires_at > ^now and not is_nil(g.boundary),
          select: g
        )
        |> Repo.all()

      merge_geofences(group_id, geofences)
    end)
  end

  defp merge_geofences(_group_id, geofences) when length(geofences) < 2, do: :ok

  defp merge_geofences(group_id, geofences) do
    ids = Enum.map(geofences, & &1.id)
    overlapping_pairs = find_overlapping_pairs(ids)
    components = union_find(ids, overlapping_pairs)

    components
    |> Enum.filter(fn {_root, members} -> length(members) > 1 end)
    |> Enum.each(fn {_root, member_ids} ->
      create_merged_geofence(group_id, member_ids)
    end)
  end

  # sobelow_skip ["SQL.Query"]
  defp find_overlapping_pairs(geofence_ids) do
    dumped_ids = Enum.map(geofence_ids, &Ecto.UUID.dump!/1)

    query = """
    SELECT a.id, b.id
    FROM geofences a, geofences b
    WHERE a.id < b.id
      AND a.id = ANY($1)
      AND b.id = ANY($1)
      AND a.boundary IS NOT NULL
      AND b.boundary IS NOT NULL
      AND ST_Intersects(a.boundary, b.boundary)
    """

    case Repo.query(query, [dumped_ids]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [a, b] -> {Ecto.UUID.cast!(a), Ecto.UUID.cast!(b)} end)

      _ ->
        []
    end
  end

  defp union_find(ids, pairs) do
    # Initialize parent map
    parent = Map.new(ids, fn id -> {id, id} end)

    # Union all overlapping pairs
    parent =
      Enum.reduce(pairs, parent, fn {a, b}, parent ->
        root_a = find(parent, a)
        root_b = find(parent, b)

        if root_a != root_b do
          Map.put(parent, root_a, root_b)
        else
          parent
        end
      end)

    # Group by root
    ids
    |> Enum.group_by(fn id -> find(parent, id) end)
  end

  defp find(parent, id) do
    case Map.get(parent, id) do
      ^id -> id
      other -> find(parent, other)
    end
  end

  defp create_merged_geofence(group_id, member_ids) do
    # Create merged geofence record
    merged =
      %MergedGeofence{}
      |> MergedGeofence.changeset(%{group_id: group_id})
      |> Repo.insert!()

    # Compute merged boundary via ST_Union
    dumped_ids = Enum.map(member_ids, &Ecto.UUID.dump!/1)

    Repo.query!(
      """
      UPDATE merged_geofences
      SET boundary = (
        SELECT ST_Union(boundary)
        FROM geofences
        WHERE id = ANY($1)
          AND boundary IS NOT NULL
      )
      WHERE id = $2
      """,
      [dumped_ids, Ecto.UUID.dump!(merged.id)]
    )

    # Link constituent geofences
    from(g in Geofence, where: g.id in ^member_ids)
    |> Repo.update_all(set: [merged_geofence_id: merged.id])
  end
end
