defmodule Fence.AccountsTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Accounts
  import Fence.Factory

  describe "register_user/1" do
    test "registers with valid attrs" do
      attrs = user_attrs()
      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == attrs["email"]
      assert user.display_name == attrs["display_name"]
      assert user.password_hash
    end

    test "hashes password with bcrypt" do
      {:ok, user} = Accounts.register_user(user_attrs())
      assert Bcrypt.verify_pass("password123", user.password_hash)
    end

    test "rejects duplicate email" do
      attrs = user_attrs()
      {:ok, _} = Accounts.register_user(attrs)
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects invalid attrs" do
      assert {:error, changeset} = Accounts.register_user(%{"email" => "bad"})
      refute changeset.valid?
    end
  end

  describe "authenticate/2" do
    test "authenticates with correct credentials" do
      user = create_user()
      assert {:ok, authed} = Accounts.authenticate(user.email, "password123")
      assert authed.id == user.id
    end

    test "rejects wrong password" do
      user = create_user()
      assert {:error, :invalid_credentials} = Accounts.authenticate(user.email, "wrongpass")
    end

    test "rejects non-existent email" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate("nope@example.com", "password123")
    end
  end

  describe "generate_tokens/1" do
    test "returns access and refresh tokens" do
      user = create_user()

      assert {:ok, %{access_token: access, refresh_token: refresh}} =
               Accounts.generate_tokens(user)

      assert is_binary(access)
      assert is_binary(refresh)
    end
  end

  describe "refresh_tokens/1" do
    test "returns new tokens from valid refresh token" do
      user = create_user()
      {:ok, %{refresh_token: refresh}} = Accounts.generate_tokens(user)
      assert {:ok, %{access_token: _, refresh_token: _}} = Accounts.refresh_tokens(refresh)
    end

    test "rejects invalid refresh token" do
      assert {:error, _} = Accounts.refresh_tokens("invalid")
    end

    test "rejects access token used as refresh" do
      user = create_user()
      {:ok, %{access_token: access}} = Accounts.generate_tokens(user)
      assert {:error, :invalid_token_type} = Accounts.refresh_tokens(access)
    end
  end

  describe "get_user/1 and get_user_by_email/1" do
    test "get_user returns user by id" do
      user = create_user()
      assert Accounts.get_user(user.id).id == user.id
    end

    test "get_user returns nil for missing id" do
      assert is_nil(Accounts.get_user(Ecto.UUID.generate()))
    end

    test "get_user_by_email returns user" do
      user = create_user()
      assert Accounts.get_user_by_email(user.email).id == user.id
    end
  end

  describe "update_user/2" do
    test "updates display_name" do
      user = create_user()
      assert {:ok, updated} = Accounts.update_user(user, %{"display_name" => "New Name"})
      assert updated.display_name == "New Name"
    end

    test "rejects invalid update" do
      user = create_user()

      assert {:error, _} =
               Accounts.update_user(user, %{"display_name" => String.duplicate("a", 101)})
    end
  end

  describe "register_device_token/3" do
    test "registers a device token" do
      user = create_user()
      assert {:ok, dt} = Accounts.register_device_token(user.id, "fcm_token", "android")
      assert dt.token == "fcm_token"
      assert dt.platform == "android"
    end

    test "upserts on conflict (same user+platform)" do
      user = create_user()
      {:ok, _} = Accounts.register_device_token(user.id, "token1", "ios")
      {:ok, dt2} = Accounts.register_device_token(user.id, "token2", "ios")
      assert dt2.token == "token2"

      tokens = Accounts.get_device_tokens(user.id)
      ios_tokens = Enum.filter(tokens, &(&1.platform == "ios"))
      assert length(ios_tokens) == 1
    end
  end

  describe "authenticate_google/1" do
    test "creates new user from Google claims" do
      claims = %{google_id: "google_123", email: unique_email(), name: "Google User"}
      assert {:ok, user} = Accounts.authenticate_google(claims)
      assert user.google_id == "google_123"
      assert user.email == claims.email
      assert user.display_name == "Google User"
      assert is_nil(user.password_hash)
    end

    test "returns existing user by google_id" do
      claims = %{google_id: "google_456", email: unique_email(), name: "Google User"}
      {:ok, first} = Accounts.authenticate_google(claims)
      {:ok, second} = Accounts.authenticate_google(claims)
      assert first.id == second.id
    end

    test "links google_id to existing email/password user" do
      user = create_user()
      claims = %{google_id: "google_789", email: user.email, name: "Google User"}
      {:ok, linked} = Accounts.authenticate_google(claims)
      assert linked.id == user.id
      assert linked.google_id == "google_789"
    end

    test "authenticate/2 returns invalid_credentials for Google-only user" do
      claims = %{google_id: "google_no_pw", email: unique_email(), name: "No Password"}
      {:ok, user} = Accounts.authenticate_google(claims)
      assert {:error, :invalid_credentials} = Accounts.authenticate(user.email, "anything")
    end
  end

  describe "request_password_reset/1" do
    test "returns :ok for existing user and enqueues email worker" do
      user = create_user()
      assert :ok = Accounts.request_password_reset(user.email)

      assert_enqueued(
        worker: Fence.Workers.PasswordResetEmailWorker,
        args: %{user_id: user.id}
      )
    end

    test "returns :ok for non-existent email (no information leak)" do
      assert :ok = Accounts.request_password_reset("nonexistent@example.com")
    end

    test "invalidates old reset codes when requesting new one" do
      user = create_user()
      Accounts.request_password_reset(user.email)
      Accounts.request_password_reset(user.email)

      # Only the latest code should be unused
      codes =
        Fence.Accounts.PasswordResetCode
        |> Ecto.Query.where([r], r.user_id == ^user.id and is_nil(r.used_at))
        |> Repo.all()

      assert length(codes) == 1
    end
  end

  describe "reset_password/3" do
    setup do
      user = create_user()
      code = Fence.Accounts.PasswordResetCode.generate_code()

      %Fence.Accounts.PasswordResetCode{}
      |> Fence.Accounts.PasswordResetCode.changeset(%{user_id: user.id, code: code})
      |> Repo.insert!()

      %{user: user, code: code}
    end

    test "resets password with valid code", %{user: user, code: code} do
      assert {:ok, updated_user} = Accounts.reset_password(user.email, code, "newpassword123")
      assert updated_user.id == user.id
      assert {:ok, _} = Accounts.authenticate(user.email, "newpassword123")
    end

    test "marks code as used after successful reset", %{user: user, code: code} do
      {:ok, _} = Accounts.reset_password(user.email, code, "newpassword123")

      # Second attempt with same code should fail (code is used, so no active codes found)
      assert {:error, :invalid_code} = Accounts.reset_password(user.email, code, "anotherpass123")
    end

    test "rejects wrong code", %{user: user} do
      assert {:error, :invalid_code} = Accounts.reset_password(user.email, "000000", "newpassword123")
    end

    test "rejects expired code" do
      user = create_user()
      code = Fence.Accounts.PasswordResetCode.generate_code()

      %Fence.Accounts.PasswordResetCode{}
      |> Fence.Accounts.PasswordResetCode.changeset(%{user_id: user.id, code: code})
      |> Ecto.Changeset.put_change(:expires_at, DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second))
      |> Repo.insert!()

      assert {:error, :code_expired} = Accounts.reset_password(user.email, code, "newpassword123")
    end

    test "rejects after max attempts exceeded" do
      user = create_user()
      code = Fence.Accounts.PasswordResetCode.generate_code()

      %Fence.Accounts.PasswordResetCode{}
      |> Fence.Accounts.PasswordResetCode.changeset(%{user_id: user.id, code: code})
      |> Ecto.Changeset.put_change(:attempts, 5)
      |> Repo.insert!()

      assert {:error, :max_attempts} = Accounts.reset_password(user.email, code, "newpassword123")
    end

    test "rejects for non-existent email" do
      assert {:error, :invalid_code} = Accounts.reset_password("nonexistent@example.com", "123456", "newpass123")
    end
  end

  describe "get_device_tokens/1" do
    test "returns all tokens for user" do
      user = create_user()
      {:ok, _} = Accounts.register_device_token(user.id, "t1", "android")
      {:ok, _} = Accounts.register_device_token(user.id, "t2", "ios")
      assert length(Accounts.get_device_tokens(user.id)) == 2
    end

    test "returns empty list for user with no tokens" do
      user = create_user()
      assert Accounts.get_device_tokens(user.id) == []
    end
  end
end
