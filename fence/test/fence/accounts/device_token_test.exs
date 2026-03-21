defmodule Fence.Accounts.DeviceTokenTest do
  use Fence.DataCase, async: true

  alias Fence.Accounts.DeviceToken

  @valid_attrs %{user_id: Ecto.UUID.generate(), token: "fcm_token_123", platform: "android"}

  describe "changeset/2" do
    test "valid attrs" do
      changeset = DeviceToken.changeset(%DeviceToken{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = DeviceToken.changeset(%DeviceToken{}, Map.delete(@valid_attrs, :user_id))
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires token" do
      changeset = DeviceToken.changeset(%DeviceToken{}, Map.delete(@valid_attrs, :token))
      assert %{token: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires platform" do
      changeset = DeviceToken.changeset(%DeviceToken{}, Map.delete(@valid_attrs, :platform))
      assert %{platform: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates platform inclusion" do
      changeset = DeviceToken.changeset(%DeviceToken{}, %{@valid_attrs | platform: "windows"})
      assert %{platform: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts ios platform" do
      changeset = DeviceToken.changeset(%DeviceToken{}, %{@valid_attrs | platform: "ios"})
      assert changeset.valid?
    end
  end
end
