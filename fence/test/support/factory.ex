defmodule Fence.Factory do
  alias Fence.{Accounts, Geofences, Groups}

  def unique_email do
    "user#{System.unique_integer([:positive])}@example.com"
  end

  def user_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "email" => unique_email(),
        "password" => "password123",
        "display_name" => "Test User"
      },
      overrides
    )
  end

  def create_user(overrides \\ %{}) do
    {:ok, user} = Accounts.register_user(user_attrs(overrides))
    user
  end

  def create_group(user, attrs \\ %{}) do
    attrs = Map.merge(%{"name" => "Test Group"}, attrs)
    {:ok, group} = Groups.create_group(user, attrs)
    group
  end

  def create_geofence(group, user, attrs \\ %{}) do
    default_attrs = %{
      "name" => "Test Geofence",
      "radius_meters" => 500.0,
      "latitude" => 37.7749,
      "longitude" => -122.4194,
      "group_id" => group.id,
      "created_by_id" => user.id,
      "expires_at" =>
        DateTime.utc_now() |> DateTime.add(7 * 24 * 3600) |> DateTime.truncate(:second)
    }

    {:ok, geofence} = Geofences.create_geofence(Map.merge(default_attrs, attrs))
    geofence
  end

  def auth_token(user) do
    {:ok, token, _claims} = Accounts.Token.generate_access_token(user)
    token
  end

  def authed_conn(conn, user) do
    token = auth_token(user)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
  end
end
