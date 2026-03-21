defmodule Fence.Notifications.PushLogTest do
  use Fence.DataCase, async: true

  alias Fence.Notifications.PushLog

  @valid_attrs %{recipient_id: Ecto.UUID.generate(), event: "entered"}

  describe "changeset/2" do
    test "valid attrs" do
      changeset = PushLog.changeset(%PushLog{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires recipient_id" do
      changeset = PushLog.changeset(%PushLog{}, Map.delete(@valid_attrs, :recipient_id))
      assert %{recipient_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires event" do
      changeset = PushLog.changeset(%PushLog{}, Map.delete(@valid_attrs, :event))
      assert %{event: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates event inclusion" do
      changeset = PushLog.changeset(%PushLog{}, %{@valid_attrs | event: "walked_by"})
      assert %{event: ["is invalid"]} = errors_on(changeset)
    end

    test "validates status inclusion" do
      changeset = PushLog.changeset(%PushLog{}, Map.put(@valid_attrs, :status, "pending"))
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "defaults status to sent" do
      log = %PushLog{}
      assert log.status == "sent"
    end
  end
end
