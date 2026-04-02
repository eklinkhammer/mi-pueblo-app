defmodule Fence.Accounts.PasswordResetCodeTest do
  use Fence.DataCase, async: true

  alias Fence.Accounts.PasswordResetCode
  import Fence.Factory

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      user = create_user()

      changeset =
        PasswordResetCode.changeset(%PasswordResetCode{}, %{user_id: user.id, code: "123456"})

      assert changeset.valid?
      assert changeset.changes[:code_hash]
      assert changeset.changes[:expires_at]
    end

    test "requires user_id" do
      changeset = PasswordResetCode.changeset(%PasswordResetCode{}, %{code: "123456"})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires code" do
      user = create_user()
      changeset = PasswordResetCode.changeset(%PasswordResetCode{}, %{user_id: user.id})
      assert %{code: ["can't be blank"]} = errors_on(changeset)
    end

    test "hashes code with bcrypt" do
      user = create_user()

      changeset =
        PasswordResetCode.changeset(%PasswordResetCode{}, %{user_id: user.id, code: "123456"})

      assert Bcrypt.verify_pass("123456", changeset.changes[:code_hash])
    end

    test "sets expires_at ~15 minutes in the future" do
      user = create_user()

      changeset =
        PasswordResetCode.changeset(%PasswordResetCode{}, %{user_id: user.id, code: "123456"})

      expires_at = changeset.changes[:expires_at]
      diff = DateTime.diff(expires_at, DateTime.utc_now())
      # Should be ~900 seconds (15 min), allow 5 second tolerance
      assert diff >= 895 and diff <= 905
    end
  end

  describe "generate_code/0" do
    test "returns a 6-digit string" do
      code = PasswordResetCode.generate_code()
      assert String.length(code) == 6
      assert String.match?(code, ~r/^\d{6}$/)
    end

    test "pads with leading zeros" do
      # Run multiple times to verify format consistency
      for _ <- 1..20 do
        code = PasswordResetCode.generate_code()
        assert String.length(code) == 6
      end
    end
  end

  describe "expired?/1" do
    test "returns true when expires_at is in the past" do
      reset_code = %PasswordResetCode{
        expires_at: DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)
      }

      assert PasswordResetCode.expired?(reset_code)
    end

    test "returns false when expires_at is in the future" do
      reset_code = %PasswordResetCode{
        expires_at: DateTime.utc_now() |> DateTime.add(60) |> DateTime.truncate(:second)
      }

      refute PasswordResetCode.expired?(reset_code)
    end
  end

  describe "used?/1" do
    test "returns true when used_at is set" do
      reset_code = %PasswordResetCode{used_at: DateTime.utc_now()}
      assert PasswordResetCode.used?(reset_code)
    end

    test "returns false when used_at is nil" do
      reset_code = %PasswordResetCode{used_at: nil}
      refute PasswordResetCode.used?(reset_code)
    end
  end

  describe "max_attempts_exceeded?/1" do
    test "returns true when attempts >= 5" do
      assert PasswordResetCode.max_attempts_exceeded?(%PasswordResetCode{attempts: 5})
      assert PasswordResetCode.max_attempts_exceeded?(%PasswordResetCode{attempts: 10})
    end

    test "returns false when attempts < 5" do
      refute PasswordResetCode.max_attempts_exceeded?(%PasswordResetCode{attempts: 0})
      refute PasswordResetCode.max_attempts_exceeded?(%PasswordResetCode{attempts: 4})
    end
  end
end
