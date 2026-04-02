defmodule Fence.Workers.CleanupPasswordResetCodesWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Accounts.PasswordResetCode
  alias Fence.Workers.CleanupPasswordResetCodesWorker
  import Fence.Factory

  describe "perform/1" do
    test "deletes codes expired more than 24 hours ago" do
      user = create_user()

      # Code expired 25 hours ago
      expired_code =
        %PasswordResetCode{}
        |> PasswordResetCode.changeset(%{user_id: user.id, code: "111111"})
        |> Ecto.Changeset.put_change(
          :expires_at,
          DateTime.utc_now() |> DateTime.add(-25 * 3600) |> DateTime.truncate(:second)
        )
        |> Repo.insert!()

      assert :ok = perform_job(CleanupPasswordResetCodesWorker, %{})
      assert is_nil(Repo.get(PasswordResetCode, expired_code.id))
    end

    test "preserves codes expired less than 24 hours ago" do
      user = create_user()

      # Code expired 1 hour ago (within 24h window)
      recent_code =
        %PasswordResetCode{}
        |> PasswordResetCode.changeset(%{user_id: user.id, code: "222222"})
        |> Ecto.Changeset.put_change(
          :expires_at,
          DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        )
        |> Repo.insert!()

      assert :ok = perform_job(CleanupPasswordResetCodesWorker, %{})
      assert Repo.get(PasswordResetCode, recent_code.id)
    end

    test "preserves non-expired codes" do
      user = create_user()

      # Code not yet expired
      active_code =
        %PasswordResetCode{}
        |> PasswordResetCode.changeset(%{user_id: user.id, code: "333333"})
        |> Repo.insert!()

      assert :ok = perform_job(CleanupPasswordResetCodesWorker, %{})
      assert Repo.get(PasswordResetCode, active_code.id)
    end

    test "handles no codes" do
      assert :ok = perform_job(CleanupPasswordResetCodesWorker, %{})
    end
  end
end
